//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./TokenReward.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Struct to track NFT lock mechanism
struct NFTLock {
    address source;
    uint256 tokenId;
    address owner;
    uint256 unlockTimestamp;
}

/**
 @title A contract to set a World Purpose
 @author Emanuele Ricci @StErMi
*/
contract NFTStaking is Ownable, ERC721Holder, ReentrancyGuard {
    using Counters for Counters.Counter;

    /// @notice TokenReward contract
    TokenReward public token;

    /// @notice Whitelist of NFT tokens accepted
    mapping(address => bool) private whitelistNFTs;

    /// @notice Amount of tokens to reward the user for each month of lock
    uint256 constant TOKEN_REWARD_PER_DAY = 3 ether;

    uint256 constant STAKE_BASE_DAYS = 31;
    uint256 constant STAKE_BASE_PERIOD = 1 days;

    /// @notice Mapping to track nft locks
    mapping(bytes32 => NFTLock) private locks;

    /// @notice NFTStaked event
    event NFTStaked(
        address indexed sender,
        address indexed source,
        uint256 indexed tokenID,
        uint256 unlockTimestamp,
        uint256 tokenAmount
    );
    /// @notice NFTUnstaked event
    event NFTUnstaked(address indexed sender, address indexed source, uint256 indexed tokenID);

    /// @notice GrantNFTWhitelist event
    event GrantNFTWhitelist(address indexed nftContract);

    /// @notice RevokeNFTWhitelist event
    event RevokeNFTWhitelist(address indexed nftContract);

    constructor(address tokenRewardAddress) {
        token = TokenReward(tokenRewardAddress);
    }

    /**
     @notice Check if an nftContract is whitelisted
     @param nftContract The NFT contract to check if whitelisted
    */
    modifier onlyWhitelisted(address nftContract) {
        bool whitelisted = whitelistNFTs[nftContract];
        require(whitelisted, "Contract is not whitelisted");

        _;
    }

    /**
     @notice Check if contract is whitelisted
     @param nftContract The NFT contract 
     @return if the nft contract is whitelisted
    */
    function isWhitelisted(address nftContract) external view returns (bool) {
        return whitelistNFTs[nftContract];
    }

    /**
     @notice Grant whitelist to an NFT contract
     @param nftContract The NFT contract to grant whitelist
    */
    function grantWhitelist(address nftContract) external onlyOwner {
        whitelistNFTs[nftContract] = true;
        emit GrantNFTWhitelist(nftContract);
    }

    /**
     @notice Revoke whitelist to an NFT contract
     @param nftContract The NFT contract to revoke whitelist
    */
    function revokeWhitelist(address nftContract) external onlyOwner {
        whitelistNFTs[nftContract] = false;
        emit RevokeNFTWhitelist(nftContract);
    }

    /**
     @notice Stake an NFT to get X amount of TokenReward
     @param source The NFT contract
     @param tokenId The NFT tokenId
     @param months Number of months the NFT will be locked. Y months -> X reward * Y
     @return lockId The lockId needed to unlock the nft after the lock period has expired
    */
    function stake(
        address source,
        uint256 tokenId,
        uint256 months
    ) external onlyWhitelisted(source) nonReentrant returns (bytes32 lockId) {
        bytes32 currentId = generateLockHashID(source, tokenId);

        IERC721(source).safeTransferFrom(msg.sender, address(this), tokenId);

        // I don't need to check if it's already staked because if it's staked the contract is the owner of the NFT
        NFTLock storage nftLock = locks[currentId];

        // Create a stake of the NFT and lock it
        uint256 unlockTimestamp = block.timestamp + (STAKE_BASE_PERIOD * STAKE_BASE_DAYS * months);
        nftLock.source = source;
        nftLock.tokenId = tokenId;
        nftLock.owner = msg.sender;
        nftLock.unlockTimestamp = unlockTimestamp;

        // Mint the reward
        uint256 tokenAmount = TOKEN_REWARD_PER_DAY * STAKE_BASE_DAYS * months;
        token.mintReward(msg.sender, tokenAmount);

        // emit event
        emit NFTStaked(msg.sender, source, tokenId, unlockTimestamp, tokenAmount);

        return currentId;
    }

    function unstake(address source, uint256 tokenId) external nonReentrant {
        bytes32 currentId = generateLockHashID(source, tokenId);
        NFTLock storage nftLock = locks[currentId];

        require(nftLock.source != address(0), "stake record not existing or already redeemed");
        require(nftLock.owner == msg.sender, "only stake owner can unstake");
        require(nftLock.unlockTimestamp < block.timestamp, "nft is still locked");

        address nftSource = nftLock.source;
        address nftOwner = nftLock.owner;
        uint256 nftTokenId = nftLock.tokenId;

        // reset the stake mapping
        delete locks[currentId];

        // Not checking that the msg.sender == owner because anyone could unstake it
        // The NFT will be anyway sent to the nftLock.owner

        IERC721(nftSource).safeTransferFrom(address(this), nftOwner, nftTokenId);

        // emit event
        emit NFTUnstaked(msg.sender, nftSource, nftTokenId);
    }

    /**
     @notice Generate the lock hash id based on source and tokenId
     @param source The NFT contract
     @param tokenId The NFT tokenId
     @return the unique id for the couple source and tokenId
    */
    function generateLockHashID(address source, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(source, "#", tokenId));
    }
}
