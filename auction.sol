// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

// uint constant MIN_BID_INCREMENT = 1.1;

contract Auction {
    struct Bid {
        address payable bidder;
        uint amount;
        bool active;
    }

    address payable private admin;
    // private
    address public highestBidder;

    uint private initialBid;
    uint public highestBid;
    uint public auctionEndTime;

    // private
    Bid[] public bids;

    // total allowed withdrawals of previous bids
    mapping(address => uint) public pendingWithdrawals;

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

    constructor() payable {
        admin = payable(msg.sender);
        state = Phase.Init;
    }

    function changeState(Phase x) private {
        require (state < x);
        state = x;
    }

    function getState() public view returns(Phase currState){
        currState = state;
    }

    function startAuction(uint _biddingTimeInMinutes, uint _initialBid) onlyAdmin public {
        auctionEndTime = block.timestamp + _biddingTimeInMinutes * 60;
        highestBid = _initialBid;
        initialBid = _initialBid;

        changeState(Phase.Start);
    }

    function endAuction() public {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");

        require(state != Phase.End, "endAuction has already been called");

        changeState(Phase.End);
        
        if (initialBid != highestBid) {
            admin.transfer(highestBid);
        }
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
            pendingWithdrawals[msg.sender] += msg.value;
        }

        bids.push(Bid(payable(msg.sender), msg.value, true));

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    // Withdraw a bid that was overbid.
    // TODO: in what phase is valid?
    function withdraw() public {
        require(msg.sender != highestBidder, "msg.sender == highestBidder");

        uint amount = pendingWithdrawals[msg.sender];

        if (amount > 0) {
            // need to set this to zero first for security
            pendingWithdrawals[msg.sender] = 0;

            if (payable(msg.sender).send(amount)) {
                for (uint i=0; i<bids.length-1; i++) {
                    if (bids[i].bidder == msg.sender) {
                        bids[i].active = false;
                    }
                }
            } else {
                pendingWithdrawals[msg.sender] = amount;
            }
        }
    }

    // use case - made mistake
    function recallBid() validPhase(Phase.Start) public returns(bool) {
        require(msg.sender == highestBidder, "msg.sender != highestBidder");

        address payable msgSenderPayable = payable(msg.sender);

        // find current highest bid
        for (uint i=bids.length-1; i>=0; i--) {
            if (bids[i].bidder == msgSenderPayable && bids[i].active) {
                uint amountToSend = bids[i].amount;

                bids[i].active = false;

                if (msgSenderPayable.send(amountToSend)) {
                    // update overall pending returns
                    pendingWithdrawals[highestBidder] -= amountToSend;

                    // set previous highest bidder as new highest
                    if (i > 0) {
                        // bool activeBidFound = false;
                        for (uint j=i-1; j>=0; j--) {
                            if (bids[j].active) {
                                highestBidder = bids[j].bidder;
                                highestBid = bids[j].amount;
                                // activeBidFound = true;
                                // break;
                                return true;
                            }
                        }

                        // if (!activeBidFound) {
                            // reset to initial state
                            highestBidder = address(0);
                            highestBid = initialBid;
                            return true;
                        // }
                    } else {
                        highestBidder = address(0);
                        highestBid = initialBid;
                        return true;
                    }
                } else {
                    // if send fails - reset previous state
                    bids[i].active = true;
                    return false;
                }

                // break;
                // return true;
            }
        }

        return false;
    }
}