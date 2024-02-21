module freelance_marketplace {

    // Imports
    use std::debug;
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};

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
        freelancer: address,
        description: vector<u8>,
        price: u64,
        escrow: Balance<SUI>,
        workSubmitted: bool,
        dispute: bool,
    }

    // Module initializer
    fun init(ctx: &mut TxContext) {
        // Initialization logic
    }

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
            freelancer: 0x0, // Set to an initial value, can be updated later
            description: description,
            price: price,
            escrow: balance::zero(),
            workSubmitted: false,
            dispute: false,
        });
    }

    public entry fun bid_on_gig(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.freelancer == 0x0, EInvalidBid);
        gig.freelancer = tx_context::sender(ctx);
    }

    public entry fun submit_work(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.freelancer == tx_context::sender(ctx), EInvalidWork);
        gig.workSubmitted = true;
    }

    public entry fun dispute_gig(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.client == tx_context::sender(ctx), EDispute);
        gig.dispute = true;
    }

    public entry fun resolve_dispute(gig_id: UID, resolved: bool, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.client == tx_context::sender(ctx), EDispute);
        assert!(!gig.dispute, EAlreadyResolved);

        if (resolved) {
            // Transfer funds to the freelancer
            transfer::public_transfer(gig.escrow, gig.freelancer);
        } else {
            // Refund funds to the client
            transfer::public_transfer(gig.escrow, gig.client);
        }

        // Reset gig state
        gig.freelancer = 0x0;
        gig.workSubmitted = false;
        gig.dispute = false;
        gig.escrow = balance::zero();
    }

    public entry fun release_payment(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.client == tx_context::sender(ctx), ENotFreelancer);
        assert!(gig.workSubmitted && !gig.dispute, EInvalidWork);

        // Transfer funds to the freelancer
        transfer::public_transfer(gig.escrow, gig.freelancer);

        // Reset gig state
        gig.freelancer = 0x0;
        gig.workSubmitted = false;
        gig.dispute = false;
        gig.escrow = balance::zero();
    }

    // Additional functions
    public entry fun cancel_gig(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.client == tx_context::sender(ctx) || gig.freelancer == tx_context::sender(ctx), ENotFreelancer);
        
        // Refund funds to the client if not yet paid
        if (gig.freelancer != 0x0 && !gig.workSubmitted && !gig.dispute) {
            transfer::public_transfer(gig.escrow, gig.client);
        }

        // Reset gig state
        gig.freelancer = 0x0;
        gig.workSubmitted = false;
        gig.dispute = false;
        gig.escrow = balance::zero();
    }

    public entry fun update_gig_description(gig_id: UID, new_description: vector<u8>, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.client == tx_context::sender(ctx), ENotFreelancer);
        gig.description = new_description;
    }

    public entry fun update_gig_price(gig_id: UID, new_price: u64, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(gig.client == tx_context::sender(ctx), ENotFreelancer);
        gig.price = new_price;
    }

    public entry fun withdraw_earnings(amount: u64, ctx: &mut TxContext) {
        // Withdraw earnings from the freelancer's balance
        let freelancer_id = object::new(ctx);
        let freelancer_balance = balance::create(amount);
        transfer::transfer(Freelancer { id: freelancer_id }, tx_context::sender(ctx), freelancer_balance);
    }

    public entry fun get_freelancer_balance(freelancer_id: UID, ctx: &mut TxContext): u64 {
        // Get the balance of a freelancer
        balance::value(&object::borrow<Freelancer>(freelancer_id, ctx))
    }

    // New functions
    public entry fun add_funds_to_gig(gig_id: UID, amount: u64, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
        let added_balance = balance::create(amount);
        balance::join(&mut gig.escrow, added_balance);
    }

    public entry fun request_refund(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
        assert!(gig.workSubmitted == false, EInvalidWithdrawal);

        // Refund funds to the client
        transfer::public_transfer(gig.escrow, gig.client);

        // Reset gig state
        gig.freelancer = 0x0;
        gig.workSubmitted = false;
        gig.dispute = false;
        gig.escrow = balance::zero();
    }

    public entry fun update_gig_deadline(gig_id: UID, new_deadline: u64, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
        // Additional logic to update the gig's deadline
    }

    public entry fun mark_gig_complete(gig_id: UID, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(tx_context::sender(ctx) == gig.freelancer, ENotFreelancer);
        gig.workSubmitted = true;
        // Additional logic to mark the gig as complete
    }

    public entry fun extend_dispute_period(gig_id: UID, extension_days: u64, ctx: &mut TxContext) {
        let gig = object::borrow_mut<FreelanceGig>(gig_id, ctx);
        assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
        assert!(gig.dispute, EInvalidUpdate);
        // Additional logic to extend the dispute period
    }
}
