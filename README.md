# Decentralized Freelance Marketplace

The Decentralized Freelance Marketplace is a smart contract-based platform built on the SUI blockchain, empowering clients and freelancers to engage in trustless transactions. The platform utilizes Move language for smart contract development, offering functionalities for creating freelance gigs, handling payments, dispute resolution, and various other features.

## Features

### 1. Creating Freelance Gigs
Clients can easily create freelance gigs by providing a description of the job and setting the price. Each gig is represented as a smart contract on the SUI blockchain.

```move
create_gig(description: vector<u8>, price: u64, ctx: &mut TxContext)
```

### Bidding and Work Submission
```move
bid_on_gig(gig_id: UID, ctx: &mut TxContext)
submit_work(gig_id: UID, ctx: &mut TxContext)
```

### Dispute Resolution
```move
dispute_gig(gig_id: UID, ctx: &mut TxContext)
resolve_dispute(gig_id: UID, resolved: bool, ctx: &mut TxContext)
```

### Payment Release and Cancellation
```move
release_payment(gig_id: UID, ctx: &mut TxContext)
cancel_gig(gig_id: UID, ctx: &mut TxContext)
```

 ### Additional Functionality
 The platform includes additional functions such as updating gig descriptions and prices, withdrawing earnings for freelancers, adding funds to gigs, requesting refunds, updating gig deadlines, marking gigs as complete, and extending dispute periods.

### Installation and Deployment

