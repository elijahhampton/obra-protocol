# WorkCore Contract

A Starknet smart contract system for managing decentralized work agreements and payments between employers and workers.

<b>NOTE: These smart contracts have not been audited are not ready for production usage.</b>

## Overview

WorkCore is a contract that facilitates:

- Creation of work agreements
- Secure escrow of payments
- Work submission and verification
- Automated payment release upon work completion

## Contract Structure

- `WorkCore.cairo`: Main contract implementation
- `interfaces/i_work_core.cairo`: Interface defining core functionality

## Key Features

- **Secure Payment Escrow**: Employer funds are held in contract until work is verified
- **Work Status Tracking**: Full lifecycle management from creation to completion
- **Verification System**: Hash-based verification of submitted work
- **Event Emission**: Comprehensive event system for tracking state changes

## Work States

1. Created
2. Funded
3. HashSubmitted
4. FullySubmitted
5. ApprovalPending
6. SubmissionDenied
7. Completed
8. Refunded
9. Closed

## Basic Usage

### Creating Work

```cairo
let work = Work {
    id: work_id,
    initiator: employer,
    initiator_sig: sig1,
    provider: worker,
    provider_sig: sig2,
    reward: amount,
    status: WorkStatus::Created
};

contract.create_work(work);
```

### Submitting Work

```cairo
contract.submit(work_id, verification_hash);
```

### Verifying Work

```cairo
contract.verify_and_complete(work_id, solution_hash);
```

## Dependencies

- Starknet
- OpenZeppelin (for ERC20 interface)
