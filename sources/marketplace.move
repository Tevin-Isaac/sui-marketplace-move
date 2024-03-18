module freelance_marketplace::marketplace {

    // Imports
    use std::debug;
    use std::option::{Self, Option};
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext, sender};
 

    // Errors
    const ENotEnough: u64 = 0;
    const EInvalidBid: u64 = 1;
    const EInvalidWork: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotFreelancer: u64 = 5;
    const EInsufficientFunds: u64 = 6;
    const EInvalidWithdrawal: u64 = 7;
    const EInvalidUpdate: u64 = 8;

    // Struct definitions
    struct Freelancer has key { id: UID }

    struct Client has key { id: UID }

    struct FreelanceGig has key, store {
        id: UID,
        client: address,
        freelancer: Option<address>,
        description: vector<u8>,
        price: u64,
        escrow: Balance<SUI>,
        workSubmitted: bool,
        dispute: bool,
    }

    // Module initializer
    // fun init(ctx: &mut TxContext) {
    //     // Initialization logic
    // }

    // Accessors
    public entry fun get_gig_description(gig: &FreelanceGig): vector<u8> {
        gig.description
    }

    public entry fun get_gig_price(gig: &FreelanceGig): u64 {
        gig.price
    }

    // Public - Entry functions
    public entry fun create_gig(description: vector<u8>, price: u64, ctx: &mut TxContext) {
        let gig_id = object::new(ctx);
        transfer::share_object(FreelanceGig {
            id: gig_id,
            client: tx_context::sender(ctx),
            freelancer: option::none(),
            description: description,
            price: price,
            escrow: balance::zero(),
            workSubmitted: false,
            dispute: false,
        });
    }

    public entry fun bid_on_gig(self: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(option::is_none(&self.freelancer), EInvalidBid);
        option::fill(&mut self.freelancer, sender(ctx));
    }

    public entry fun submit_work(self: &mut FreelanceGig, ctx: &mut TxContext) {
        let freelancer = option::borrow(&self.freelancer);
        assert!(*freelancer == tx_context::sender(ctx), EInvalidWork);
        self.workSubmitted = true;
    }

    public entry fun dispute_gig(self: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(self.client == tx_context::sender(ctx), EDispute);
        self.dispute = true;
    }

    public entry fun resolve_dispute<T>(self: &mut FreelanceGig, resolved: bool, ctx: &mut TxContext) {
        assert!(self.client == tx_context::sender(ctx), EDispute);
        assert!(!self.dispute, EAlreadyResolved);

        let balance = balance::withdraw_all<SUI>(&mut self.escrow);
        let coin = coin::from_balance<SUI>(balance, ctx);

        let freelancer = option::borrow(&self.freelancer);

        if (resolved) {
            // Transfer funds to the freelancer
            transfer::public_transfer(coin, *freelancer);
        } else {
            // Refund funds to the client
            transfer::public_transfer(coin, self.client);
        };

        // Reset gig state
        self.freelancer = option::none();
        self.workSubmitted = false;
        self.dispute = false;
    }

    public entry fun release_payment(self: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(self.client == tx_context::sender(ctx), ENotFreelancer);
        assert!(self.workSubmitted && !self.dispute, EInvalidWork);

        let balance = balance::withdraw_all<SUI>(&mut self.escrow);
        let coin = coin::from_balance<SUI>(balance, ctx);

        let freelancer = option::borrow(&self.freelancer);
        // Transfer funds to the freelancer
        transfer::public_transfer(coin, *freelancer);

        // Reset gig state
        self.freelancer = option::none();
        self.workSubmitted = false;
        self.dispute = false;
    }

    // // Additional functions
    public entry fun cancel_gig(self: &mut FreelanceGig, ctx: &mut TxContext) {
        let freelancer = option::borrow(&self.freelancer);
        assert!(self.client == tx_context::sender(ctx) || *freelancer == tx_context::sender(ctx), ENotFreelancer);

        let balance = balance::withdraw_all<SUI>(&mut self.escrow);
        let coin = coin::from_balance<SUI>(balance, ctx);

        // Refund funds to the client if not yet paid
        if (option::is_some(&self.freelancer) && !self.workSubmitted && !self.dispute) {
            transfer::public_transfer(coin, self.client);
        }
        else {
            abort EInvalidWork
        };

       // Reset gig state
        self.freelancer = option::none();
        self.workSubmitted = false;
        self.dispute = false;
    }

    public entry fun update_gig_description(self: &mut FreelanceGig, new_description: vector<u8>, ctx: &mut TxContext) {
        assert!(self.client == tx_context::sender(ctx), ENotFreelancer);
        self.description = new_description;
    }

    public entry fun update_gig_price(self: &mut FreelanceGig, new_price: u64, ctx: &mut TxContext) {
        assert!(self.client == tx_context::sender(ctx), ENotFreelancer);
        self.price = new_price;
    }

    // I REALLY DONT UNDERSTAND WHAT DiD YOU DO HERE 
    // public entry fun withdraw_earnings(amount: u64, ctx: &mut TxContext) {
    //     // Withdraw earnings from the freelancer's balance
    //     let freelancer_id = object::new(ctx);
    //     let freelancer_balance = balance::create(amount);
    //     transfer::transfer(Freelancer { id: freelancer_id }, tx_context::sender(ctx), freelancer_balance);
    // }

    // public entry fun get_freelancer_balance(freelancer_id: UID, ctx: &mut TxContext): u64 {
    //     // Get the balance of a freelancer
    //     balance::value(&object::borrow<Freelancer>(freelancer_id, ctx))
    // }

    // New functions
    public entry fun add_funds_to_gig(self: &mut FreelanceGig, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == self.client, ENotFreelancer);
        let balance = coin::into_balance(amount);
        balance::join(&mut self.escrow, balance);
    }

    public entry fun request_refund(self: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == self.client, ENotFreelancer);
        assert!(self.workSubmitted == false, EInvalidWithdrawal);

        let balance = balance::withdraw_all<SUI>(&mut self.escrow);
        let coin = coin::from_balance<SUI>(balance, ctx);

        // Refund funds to the client
        transfer::public_transfer(coin, self.client);

         // Reset gig state
        self.freelancer = option::none();
        self.workSubmitted = false;
        self.dispute = false;
    }

    // Unused Function

    // public entry fun update_gig_deadline(gig_id: UID, new_deadline: u64, ctx: &mut TxContext) {
    //     let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
    //     assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
    //     // Additional logic to update the gig's deadline
    // }

    public entry fun mark_gig_complete(self: &mut FreelanceGig, ctx: &mut TxContext) {
        let freelancer = option::borrow(&self.freelancer);
        assert!(tx_context::sender(ctx) == *freelancer, ENotFreelancer);
        self.workSubmitted = true;
        // Additional logic to mark the gig as complete
    }

       // Unused Function

    // public entry fun extend_dispute_period(gig_id: UID, extension_days: u64, ctx: &mut TxContext) {
    //     let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
    //     assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
    //     assert!(gig.dispute, EInvalidUpdate);
    //     // Additional logic to extend the dispute period
    // }
}
