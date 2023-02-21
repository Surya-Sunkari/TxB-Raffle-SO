//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Raffle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Custom Errors
error InvalidAmount();
error InsufficientLINKBalance();
error InsufficientLINKAllowance();

// INITIALIZED TO GOERLI - NOT STANDARDIZED
contract RaffleFactory is Ownable {
    IERC20 public linkToken;
    uint256 public fee;
    bytes32 public keyHash;
    address public linkTokenAddress;
    address public vrfCoordinator;

    event RaffleCreated(
        address indexed raffle,
        address indexed nftOwner,
        address indexed nftContract,
        uint256 nftID,
        uint256 ticketPrice,
        uint256 minTickets
    );

    constructor() Ownable() {
        fee = 0.1 * 10 ** 18; //0.1 LINK
        keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
        linkTokenAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
        linkToken = IERC20(linkTokenAddress);
        vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    }

    function createRaffle(
        address _nftContract,
        uint256 _nftID,
        uint256 _endTime,
        uint256 _ticketFee,
        uint256 _minTickets
    ) external {
        if (_ticketFee <= 0 || _minTickets == 0) {
            revert InvalidAmount();
        }

        Raffle raffle = new Raffle(
            payable(msg.sender),
            _ticketFee,
            _endTime,
            _minTickets,
            _nftContract,
            _nftID,
            keyHash,
            fee
        );
        emit RaffleCreated(
            address(raffle),
            msg.sender,
            _nftContract,
            _nftID,
            _ticketFee,
            _minTickets
        );

        if (linkToken.allowance(msg.sender, address(this)) < fee) {
            revert InsufficientLINKAllowance();
        }

        if (linkToken.balanceOf(msg.sender) < fee) {
            revert InsufficientLINKBalance();
        }
    }

    function ownerWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
