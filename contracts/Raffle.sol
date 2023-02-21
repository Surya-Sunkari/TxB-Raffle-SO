//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// Custom Errors
error InsufficientAmount();
error InvalidTicketAmount();
error RaffleOngoing();
error RaffleNotOpen();
error ContractNotHoldingNFT();
error InsufficientTicketsLeft();
error InsufficientTicketsBought();
error RandomNumberStillLoading();
error WinnerAlreadyChosen();
error OnlyNFTOwnerCanAccess();
error NoBalance();
error TooShort();

contract Raffle is Ownable, VRFConsumerBase {
    // Raffle Content
    address payable public nftOwner;
    uint256 public immutable ticketFee;
    uint256 public immutable endTime;
    uint256 public immutable minTickets;
    address public immutable nftContract;
    uint256 public immutable nftID;
    address payable winner;

    // Chainlink Content
    bytes32 internal keyHash;
    uint256 internal fee;
    address internal vrfCoordinator;
    address internal linkToken;
    uint256 internal randomNumber = type(uint256).max;
    bool public randomNumberRequested;

    // Player Content
    address payable[] public players;
    mapping(address => uint256) public playerTickets;

    // Events
    event RaffleEntered(address indexed player, uint256 numPurchased);
    event RaffleRefunded(address indexed player, uint256 numRefunded);
    event RaffleWinner(address indexed winner);

    constructor(
        address payable _nftOwner,
        uint256 _ticketFee,
        uint256 _endTime,
        uint256 _minTickets,
        address _nftContract,
        uint256 _nftID,
        bytes32 _keyHash,
        uint256 _fee
    ) Ownable() VRFConsumerBase(vrfCoordinator, linkToken) {
        nftOwner = payable(_nftOwner);
        ticketFee = _ticketFee;
        endTime = _endTime;
        minTickets = _minTickets;
        nftContract = _nftContract;
        nftID = _nftID;
        keyHash = _keyHash;
        fee = _fee;
    }

    // Only the owner of the raffle can access this function.
    modifier onlynftOwner() {
        if (msg.sender != nftOwner) {
            revert OnlyNFTOwnerCanAccess();
        }
        _;
    }

    // Function only executes if contract is holding the NFT.
    modifier nftHeld() {
        if (IERC721(nftContract).ownerOf(nftID) != address(this)) {
            revert ContractNotHoldingNFT();
        }
        _;
    }

    // Function only executes if random number was not chosen yet.
    modifier vrfCalled() {
        if (randomNumberRequested == true) {
            revert WinnerAlreadyChosen();
            _;
        }
    }

    // Function only executes if minimum ticket threshold is met
    modifier enoughTickets() {
        if (players.length < minTickets) {
            revert InsufficientTicketsBought();
        }
        _;
    }

    // Enter the NFT raffle
    function enterRaffle(uint256 _numTickets) external payable nftHeld {
        if (block.timestamp > endTime) {
            revert RaffleNotOpen();
        }

        if (_numTickets <= 0) {
            revert InvalidTicketAmount();
        }

        if (msg.value < ticketFee * _numTickets) {
            revert InsufficientAmount();
        }

        for (uint256 i = 0; i < _numTickets; i++) {
            players.push(payable(msg.sender));
        }

        playerTickets[msg.sender] += _numTickets;

        emit RaffleEntered(msg.sender, _numTickets);
    }

    function exitRaffle(uint256 _numTickets) external nftHeld vrfCalled {
        if (playerTickets[msg.sender] < _numTickets) {
            revert InsufficientTicketsBought();
        }

        uint256 nt = _numTickets;
        uint256 i = 0;
        while (i < players.length && nt > 0) {
            if (players[i] != msg.sender) {
                i++;
            } else {
                players[i] = players[players.length - 1];
                players.pop();
                payable(msg.sender).transfer(ticketFee);
                nt--;
                playerTickets[msg.sender] = playerTickets[msg.sender] -= 1;
            }
        }

        emit RaffleRefunded(msg.sender, _numTickets);
    }

    function receiveRandomWinner()
        external
        enoughTickets
        vrfCalled
        returns (bytes32 requestId)
    {
        randomNumberRequested = true;

        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(
        bytes32 requestId,
        uint256 randomness
    ) internal override enoughTickets {
        randomNumber = randomness;
    }

    function disbursement() external nftHeld enoughTickets {
        if (randomNumber == type(uint).max) {
            revert RandomNumberStillLoading();
        }

        if (randomNumberRequested != true) {
            revert RaffleOngoing();
        }

        if (address(this).balance == 0) {
            revert NoBalance();
        }

        winner = payable(players[randomNumber % players.length]);
        payable(nftOwner).transfer((address(this).balance * 975) / 1000);
        IERC721(nftContract).safeTransferFrom(address(this), winner, nftID);
        payable(owner()).transfer((address(this).balance)); // 2.5% commission of ticket fees
        emit RaffleWinner(winner);
    }

    function deleteRaffle() external onlynftOwner nftHeld vrfCalled {
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, nftID);

        for (uint256 i = players.length - 1; i >= 0; i--) {
            payable(players[i]).transfer(ticketFee);
            players.pop();
        }
    }
}
