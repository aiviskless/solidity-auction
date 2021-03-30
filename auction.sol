// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Auction {
    struct Bid {
        address payable bidder;
        uint amount;
        bool active;
    }

    address payable private admin;
    // TODO: set to private
    address public highestBidder;

    uint private initialBid;
    // TODO: set to private
    uint public highestBid;
    // TODO: set to private
    uint public auctionEndTime;

    // TODO: set to private
    Bid[] public bids;

    // total allowed withdrawal amount of all bids for each bidder
    // TODO: set to private
    mapping(address => uint) public bidderFunds;

    enum Phase { Init, Start, End, Cancel }
    Phase public state = Phase.End;

    constructor() payable {
        admin = payable(msg.sender);
        state = Phase.Init;
    }

    // modifiers
    modifier validPhase(Phase reqPhase) {
        require(state == reqPhase, "Wrong Phase");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin might call this function");
        _;
    }
    /////////////////

    // view functions
    function getState() public view returns(Phase currState){
        currState = state;
    }

    function getAuctionEndTime() public view returns(uint){
        return auctionEndTime;
    }

    function getHighestBid() public view returns (uint) {
        return highestBid;
    }
    /////////////////

    function changeState(Phase x) private {
        require (state < x);

        state = x;
    }

    function startAuction(uint _biddingTimeInMinutes, uint _initialBid) validPhase(Phase.Init) onlyAdmin public {
        auctionEndTime = block.timestamp + _biddingTimeInMinutes * 60;
        highestBid = _initialBid;
        initialBid = _initialBid;

        changeState(Phase.Start);
    }

    function endAuction() validPhase(Phase.Start) onlyAdmin public {
        require(block.timestamp >= auctionEndTime, "Auction end time not yet exceeded");
        require(state != Phase.End, "endAuction has already been called");
        require(state != Phase.Cancel, "cancelAuction has already been called");

        changeState(Phase.End);

        if (initialBid != highestBid) {
            // admin receives money
            admin.transfer(highestBid);
            // reduce amount that winner can withdraw back from previous bids
            bidderFunds[highestBidder] -= highestBid;
        }
    }

    function cancelAuction() validPhase(Phase.Start) onlyAdmin public {
        changeState(Phase.Cancel);
    }

    function bid() public validPhase(Phase.Start) payable {
        require(block.timestamp <= auctionEndTime, "Auction already ended");
        require(msg.value > highestBid, "There already is a higher bid");
        require(msg.sender != admin, "Administrator can not bid");
        require(msg.sender != highestBidder, "You can not overbid your bid");

        if (highestBid != 0) {
            // add to amount to be withdrawn after auction
            bidderFunds[msg.sender] += msg.value;
        }

        bids.push(Bid(payable(msg.sender), msg.value, true));

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    // withdraw a bid(s) that was overbid
    function withdraw() public {
        // highest bidder can not withdraw all funds while auction is active
        if (state != Phase.End && state != Phase.Cancel) {
            require(msg.sender != highestBidder, "msg.sender == highestBidder");
        }

        uint amount = bidderFunds[msg.sender];

        if (amount > 0) {
            // reset funds - need to set this to zero first for security
            bidderFunds[msg.sender] = 0;

            if (payable(msg.sender).send(amount)) {
                for (uint i=0; i<bids.length-1; i++) {
                    if (bids[i].bidder == msg.sender) {
                        // set bid as inactove
                        bids[i].active = false;
                    }
                }
            } else {
                // handle failed send()
                bidderFunds[msg.sender] = amount;
            }
        }
    }

    // use case - bidder entered unintented bid amount
    function recallBid() validPhase(Phase.Start) public returns(bool) {
        // only highest bidder can recall bid - others use withdraw()
        require(msg.sender == highestBidder, "msg.sender != highestBidder");

        address payable msgSenderPayable = payable(msg.sender);

        // find current highest bid
        for (uint i=bids.length-1; i>=0; i--) {
            if (bids[i].bidder == msgSenderPayable && bids[i].active) {
                uint amountToSend = bids[i].amount;

                bids[i].active = false;

                if (msgSenderPayable.send(amountToSend)) {
                    // subtract from amount to be withdrawn after auction
                    bidderFunds[highestBidder] -= amountToSend;

                    // set previous highest bidder as new highest
                    if (i > 0) {
                        for (uint j=i-1; j>=0; j--) {
                            if (bids[j].active) {
                                highestBidder = bids[j].bidder;
                                highestBid = bids[j].amount;

                                return true;
                            }
                        }

                        // reset to initial state
                        highestBidder = address(0);
                        highestBid = initialBid;

                        return true;
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
            }
        }

        return false;
    }
}