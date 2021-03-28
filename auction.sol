pragma solidity >=0.7.0 <0.9.0;

uint constant MIN_BID_INCREMENT = 1.1;

contract Auction {
    address payable public admin;
    uint public auctionEndTime;

    address public highestBidder;
    uint public highestBid;

    // Allowed withdrawals of previous bids
    mapping(address => uint) pendingReturns;

    bool ended;

    constructor(uint _biddingTime, uint _initialBid, address payable _admin) {
        admin = _admin;
        auctionEndTime = block.timestamp + _biddingTime;
        highestBid = _initialBid;
    }
    
    function getMinimumAmountToBid() public view returns(uint) {
        return highestBid * MIN_BID_INCREMENT;
    }

    function bid() public payable {
        // Revert the call if the bidding period is over.
        require(block.timestamp <= auctionEndTime, "Auction already ended");

       
        require(msg.value > highestBid, "There already is a higher bid");

        require(msg.sender != admin, "Administrator can not bid");

        if (highestBid != 0) {
            
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    // Withdraw a bid that was overbid.
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

    function auctionEnd() public {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!ended, "auctionEnd has already been called");

        ended = true;

        // transfer vs send?
        admin.transfer(highestBid);
    }
}