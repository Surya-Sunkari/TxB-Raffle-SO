//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Raffle.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Custom Errors
error InvalidAmount();
error InsufficientLINKBalance();
error InsufficientLINKAllowance();

contract RaffleFactory is Ownable {
    address internal supraAddress =
        address(0xE1Ac002c6149585a6f499e6C2A03f15491Cb0D04); //Initialized to Ethereum Goerli Testnet

    event RaffleCreated(
        address indexed raffle,
        address indexed nftOwner,
        address indexed nftContract,
        uint256 nftID,
        uint256 ticketPrice,
        uint256 minTickets
    );

    constructor() Ownable() {}

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
            supraAddress
        );
        emit RaffleCreated(
            address(raffle),
            msg.sender,
            _nftContract,
            _nftID,
            _ticketFee,
            _minTickets
        );

        //     if (linkToken.allowance(msg.sender, address(this)) < fee) {
        //         revert InsufficientLINKAllowance();
        //     }

        //     if (linkToken.balanceOf(msg.sender) < fee) {
        //         revert InsufficientLINKBalance();
        //     }
    }

    function ownerWithdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
