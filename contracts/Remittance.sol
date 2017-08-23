pragma solidity ^0.4.6;

contract Remittance {

    address owner;
    uint maxDeadline;
    uint fee;
    //if we need to destroy current contract, must be sure
    //no new transfer requests enter
    bool destroying;
    uint pendingTransfers;
    uint currentTransfer;

    struct TransferRequest {
        address sender;
        address target;
        address finalTarget;
        uint amount;
        uint deadline;
        bytes32 firstHash;
        bytes32 secondHash;
        bool abortRequested;
        string comments;
        uint transferFee;
        bool delivered;
    }
    
    mapping (uint => TransferRequest) transferStack;
    
    event NewTransferRequested(uint transferId, address sender, 
                               address target, address finalTarget,uint amount,
                               uint deadline,string comments);
    event AbortTransferRequested();
    event TransferFulfilled(uint transferId,uint amount);
    event ContractTerminationRequested();
    event FeeChanged(uint newFee);

    
    function Remittance()
        public
        {
            owner = msg.sender;
            maxDeadline =  100;
            pendingTransfers = 0;
            currentTransfer = 0;
            destroying = false;
        }
    
    function RequestTransfer
        (address requestedTarget, address requestedFinalTarget, string requestedComments,
         bytes32 requestedFirstHash, bytes32 requestedSecondHash, uint requestedDeadline) 
        public
        payable
        returns (bool success) {
            //we first check if this contract isn't destroying himself
            if (destroying) {
                return false;
            }
            //the deadline can't exceed the max deadline for
            //this contract
            if (requestedDeadline > maxDeadline) {
                return false;
            }
            //we need enough Ether to cover the fees
            if (fee > msg.value) revert();
            //Final destination can't be the same of the exchange
            if (requestedFinalTarget ==  requestedTarget || 
                requestedTarget == msg.sender || 
                requestedFinalTarget == msg.sender) revert();
            
            //We're ready to add this transfer request to the stack
            transferStack[currentTransfer]=TransferRequest(msg.sender,requestedTarget,requestedFinalTarget,
                                msg.value,block.number + requestedDeadline, requestedFirstHash,requestedSecondHash,
                                false,requestedComments,fee,false);
            NewTransferRequested(currentTransfer,msg.sender,requestedTarget,requestedFinalTarget,msg.value,
                                block.number + requestedDeadline,requestedComments);
            currentTransfer++;
            pendingTransfers++;
            return true;
        }

        function CheckTransfer(uint transferId) 
            public
            constant
            returns (address destination,uint amount)
            {
                 return (transferStack[transferId].target,transferStack[transferId].amount);
            }
        
    //If business going good or bad, maybe change the fee is a good idea
    function changeFee(uint newFee) 
        public
        returns (bool result)    
    {
        //only owner can do this
        if (msg.sender != owner) revert();
        fee = newFee;
        FeeChanged(newFee);
        return true;
    }
    
    function ValidateTransfer(uint transferId, string firstPassword, string secondPassword)
        public
        returns (bool result)
        {
            //check if transaction exists and isn't already payed
            TransferRequest memory transfer = transferStack[transferId];
            if (transfer.delivered == true || transfer.amount == 0) return false;
            if (transfer.firstHash != keccak256(firstPassword) || transfer.secondHash != keccak256(secondPassword)) {
                return false;
            }
            //everything OK to pay
            transfer.target.transfer(transfer.amount - transfer.transferFee);
            owner.transfer(transfer.transferFee);
            transfer.delivered = true;
            transferStack[transferId] = transfer;
            TransferFulfilled(transferId,transfer.amount);
            return true;
        }
    
}
