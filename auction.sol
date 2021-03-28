// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// uint constant MIN_BID_INCREMENT = 1.1;

contract Auction {
    address payable public admin;
    address public highestBidder;

    uint public highestBid;
    uint public auctionEndTime;

    // Allowed withdrawals of previous bids
    // TODO: should rename this var
    mapping(address => uint) pendingReturns;

    enum Phase { Init, Start, End }
    Phase public state = Phase.End;

    // modifiers
    modifier validPhase(Phase reqPhase) {
        require(state == reqPhase, "Wrong Phase");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin might call this function");
        _;
    }

    constructor(address payable _admin) {
        admin = _admin;
        state = Phase.Init;
    }

    function changeState(Phase x) private {
        require (state < x);
        state = x;
    }

    function getState() public view returns(Phase currState){
        currState = state;
    }

    function startAuction(uint _biddingTime, uint _initialBid) onlyAdmin public {
        auctionEndTime = block.timestamp + _biddingTime;
        highestBid = _initialBid;

        changeState(Phase.Start);
    }

    function endAuction() public {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");

        require(state != Phase.End, "endAuction has already been called");

        changeState(Phase.End);

        // transfer vs send?
        admin.transfer(highestBid);
    }

    // TODO: function cancelAuction?????
    // function cancelAuction() onlyOwner onlyBeforeEnd onlyNotCanceled returns (bool success) {
    //     canceled = true;
    //     LogCanceled();
    //     return true;
    // }
    
    // function getMinimumAmountToBid() public view returns(uint) {
    //     return highestBid * MIN_BID_INCREMENT;
    // }

    function bid() public validPhase(Phase.Start) payable {
        // Revert the call if the bidding period is over.
        require(block.timestamp <= auctionEndTime, "Auction already ended");

        require(msg.value > highestBid, "There already is a higher bid");

        require(msg.sender != admin, "Administrator can not bid");

        require(msg.sender != highestBidder, "You can not overbid your bid");

        if (highestBid != 0) {
            
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    // Withdraw a bid that was overbid.
    // TODO: in what phase is valid?
    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            // need to set this to zero first for security
            pendingReturns[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    // function cancelBid() public returns (bool) {
    //     require(msg.sender == highestBidder, "You can only cancel your own bid");
    // // highestBidder ????
    //     uint amount = highestBid;
    //     highestBid = 0;
    //     bids[bidIterator].bidderAddress.transfer(amount);
    // }
}