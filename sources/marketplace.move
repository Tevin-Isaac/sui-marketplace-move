module freelance_marketplace::freelance_marketplace {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some, is_some, contains, borrow};

    // Errors
    const EInvalidBid: u64 = 1;
    const EInvalidWork: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotFreelancer: u64 = 5;
    const EInvalidWithdrawal: u64 = 7;

    // Struct definitions
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
            freelancer: none(), // Set to an initial value, can be updated later
            description: description,
            price: price,
            escrow: balance::zero(),
            workSubmitted: false,
            dispute: false,
        });
    }

    public entry fun bid_on_gig(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(!is_some(&gig.freelancer), EInvalidBid);
        gig.freelancer = some(tx_context::sender(ctx));
    }

    public entry fun submit_work(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(contains(&gig.freelancer, &tx_context::sender(ctx)), EInvalidWork);
        gig.workSubmitted = true;
    }

    public entry fun dispute_gig(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(gig.client == tx_context::sender(ctx), EDispute);
        gig.dispute = true;
    }

    public entry fun resolve_dispute(gig: &mut FreelanceGig, resolved: bool, ctx: &mut TxContext) {
        assert!(gig.client == tx_context::sender(ctx), EDispute);
        assert!(gig.dispute, EAlreadyResolved);
        assert!(is_some(&gig.freelancer), EInvalidBid);
        let escrow_amount = balance::value(&gig.escrow);
        let escrow_coin = coin::take(&mut gig.escrow, escrow_amount, ctx);
        if (resolved) {
            let freelancer = *borrow(&gig.freelancer);
            // Transfer funds to the freelancer
            transfer::public_transfer(escrow_coin, freelancer);
        } else {
            // Refund funds to the client
            transfer::public_transfer(escrow_coin, gig.client);
        };

        // Reset gig state
        gig.freelancer = none();
        gig.workSubmitted = false;
        gig.dispute = false;
    }

    public entry fun release_payment(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(gig.client == tx_context::sender(ctx), ENotFreelancer);
        assert!(gig.workSubmitted && !gig.dispute, EInvalidWork);
        assert!(is_some(&gig.freelancer), EInvalidBid);
        let freelancer = *borrow(&gig.freelancer);
        let escrow_amount = balance::value(&gig.escrow);
        let escrow_coin = coin::take(&mut gig.escrow, escrow_amount, ctx);
        // Transfer funds to the freelancer
        transfer::public_transfer(escrow_coin, freelancer);

        // Reset gig state
        gig.freelancer = none();
        gig.workSubmitted = false;
        gig.dispute = false;
    }

    // Additional functions
    public entry fun cancel_gig(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(gig.client == tx_context::sender(ctx) || contains(&gig.freelancer, &tx_context::sender(ctx)), ENotFreelancer);
        
        // Refund funds to the client if not yet paid
        if (is_some(&gig.freelancer) && !gig.workSubmitted && !gig.dispute) {
            let escrow_amount = balance::value(&gig.escrow);
            let escrow_coin = coin::take(&mut gig.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, gig.client);
        };

        // Reset gig state
        gig.freelancer = none();
        gig.workSubmitted = false;
        gig.dispute = false;
    }

    public entry fun update_gig_description(gig: &mut FreelanceGig, new_description: vector<u8>, ctx: &mut TxContext) {
        assert!(gig.client == tx_context::sender(ctx), ENotFreelancer);
        gig.description = new_description;
    }

    public entry fun update_gig_price(gig: &mut FreelanceGig, new_price: u64, ctx: &mut TxContext) {
        assert!(gig.client == tx_context::sender(ctx), ENotFreelancer);
        gig.price = new_price;
    }

    // New functions
    public entry fun add_funds_to_gig(gig: &mut FreelanceGig, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut gig.escrow, added_balance);
    }

    public entry fun request_refund(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
        assert!(gig.workSubmitted == false, EInvalidWithdrawal);
        let escrow_amount = balance::value(&gig.escrow);
        let escrow_coin = coin::take(&mut gig.escrow, escrow_amount, ctx);
        // Refund funds to the client
        transfer::public_transfer(escrow_coin, gig.client);

        // Reset gig state
        gig.freelancer = none();
        gig.workSubmitted = false;
        gig.dispute = false;
    }

    // public entry fun update_gig_deadline(gig: &mut FreelanceGig, new_deadline: u64, ctx: &mut TxContext) {
    //     assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
    //     // Additional logic to update the gig's deadline
    // }

    public entry fun mark_gig_complete(gig: &mut FreelanceGig, ctx: &mut TxContext) {
        assert!(contains(&gig.freelancer, &tx_context::sender(ctx)), ENotFreelancer);
        gig.workSubmitted = true;
        // Additional logic to mark the gig as complete
    }

    // public entry fun extend_dispute_period(gig: &mut FreelanceGig, extension_days: u64, ctx: &mut TxContext) {
    //     assert!(tx_context::sender(ctx) == gig.client, ENotFreelancer);
    //     assert!(gig.dispute, EInvalidUpdate);
    //     // Additional logic to extend the dispute period
    // }
}
