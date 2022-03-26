pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Liquid {
    address liquid11;
    uint256 auctionIndex;

    mapping(uint256 => Auction) public auctions;
    struct Auction {
        uint256 totalTokenPool;
        uint256 auctionAmount;
        uint256 minAuctionPrice;
        uint256 auctionLength;
        uint256 startTime;
        uint256 totalRaised;
        address protocolTreasuryAddress;
        address protocolToken;
        address otherToken;
        address routerAddress;
        bool auctionDidNotPass;
        bool auctionFinalized;
    }

    mapping(address => mapping(uint256 => UserContribution))
        public userContributions;

    struct UserContribution {
        uint256 amount;
    }

    constructor() {
        liquid11 = msg.sender;
    }

    modifier auctionOpen(uint256 _auctionIndex) {
        require(
            block.timestamp > auctions[_auctionIndex].startTime &&
                block.timestamp <
                auctions[_auctionIndex].startTime +
                    auctions[_auctionIndex].auctionLength,
            "Auction not open"
        );
        _;
    }

    function createAuction(
        uint256 _totalTokenAmount,
        uint256 _auctionAmount,
        uint256 _minAuctionPrice,
        uint256 _auctionLength,
        uint256 _startTime,
        address _protocolToken,
        address _otherToken,
        address _routerAddress
    ) external {
        auctionIndex++;

        // This include also bonus incentive tokens.
        require(
            _totalTokenAmount >= 2 * _auctionAmount,
            "insufcient auction funds"
        );

        // give us the juice
        IERC20(_protocolToken).transfer(address(this), _totalTokenAmount);

        // set what we need for the auctionzs
        auctions[auctionIndex].auctionAmount = _auctionAmount;
        auctions[auctionIndex].minAuctionPrice = _minAuctionPrice;
        auctions[auctionIndex].auctionLength = _auctionLength;
        auctions[auctionIndex].protocolToken = _protocolToken;
        auctions[auctionIndex].otherToken = _otherToken;
        auctions[auctionIndex].routerAddress = _routerAddress;
        auctions[auctionIndex].protocolTreasuryAddress = msg.sender;

        // auction start ser
        require(
            block.timestamp + 1 hours < _startTime,
            "auction already started"
        );
        // also check reasonable start time paratmeter.
        auctions[auctionIndex].startTime = _startTime;
    }

    // ape into the sepcific liquidity event
    function ape(uint256 _auctionIndex, uint256 _amountToApe)
        external
        auctionOpen(_auctionIndex)
    {
        require(_amountToApe > 0, "ape harder");
        // enforce not too much ape edge case after hack.
        IERC20(auctions[auctionIndex].otherToken).transfer(
            address(this),
            _amountToApe
        );

        userContributions[msg.sender][_auctionIndex].amount += _amountToApe;
        auctions[auctionIndex].totalRaised += _amountToApe;
    }

    // ape out of the sepcific liquidity event
    function unApe(uint256 _auctionIndex, uint256 _amountToApeOut)
        external
        auctionOpen(_auctionIndex)
    {
        require(
            _amountToApeOut <=
                userContributions[msg.sender][_auctionIndex].amount,
            "naughty ape"
        );

        userContributions[msg.sender][_auctionIndex].amount -= _amountToApeOut;
        auctions[auctionIndex].totalRaised -= _amountToApeOut;

        IERC20(auctions[auctionIndex].otherToken).transfer(
            msg.sender,
            _amountToApeOut
        );
    }

    function finalizeAuction(uint256 _auctionIndex) external {
        require(
            block.timestamp >
                auctions[_auctionIndex].startTime +
                    auctions[_auctionIndex].auctionLength,
            "Auction not ended"
        );
        require(
            !auctions[_auctionIndex].auctionFinalized,
            "auction not finalized"
        );

        auctions[_auctionIndex].auctionFinalized = true;

        if (
            auctions[_auctionIndex].totalRaised <
            auctions[_auctionIndex].minAuctionPrice
        ) {
            auctions[_auctionIndex].auctionDidNotPass = true;
            return; // auction didn't pass people should withdraw.
        }

        Auction memory auction = auctions[auctionIndex];

        // give router the necessary allowance.
        IUniswapV2Router02(auction.routerAddress).addLiquidity(
            auction.protocolToken,
            auction.otherToken,
            123, // amountADesired
            123,
            100, // amountAmin
            100,
            address(this),
            123
        );

        // perform work!
    }

    function withdrawFailedEvent(uint256 _auctionIndex) external {
        require(
            auctions[auctionIndex].auctionDidNotPass,
            "can only exit in failed event"
        );
        uint256 amount = userContributions[msg.sender][_auctionIndex].amount;
        userContributions[msg.sender][_auctionIndex].amount = 0;

        IERC20(auctions[auctionIndex].otherToken).transfer(msg.sender, amount);
    }

    function withdrawFailedEventProtocol(uint256 _auctionIndex) external {
        require(
            auctions[auctionIndex].auctionDidNotPass,
            "can only exit in failed event"
        );
        uint256 amount = auctions[auctionIndex].totalTokenPool;
        auctions[auctionIndex].totalTokenPool = 0;

        IERC20(auctions[auctionIndex].protocolToken).transfer(
            auctions[auctionIndex].protocolTreasuryAddress,
            amount
        );
    }
}
