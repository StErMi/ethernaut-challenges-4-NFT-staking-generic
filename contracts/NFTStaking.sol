//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "./TokenReward.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

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
contract NFTStaking is ERC721Holder {
    using Counters for Counters.Counter;

    /// @notice utility to track staked NFT
    Counters.Counter private _lockIds;

    /// @notice TokenReward contract
    TokenReward public token;

    /// @notice Amount of tokens to reward the user for each month of lock
    uint256 constant TOKEN_REWARD_PER_DAY = 3 ether;

    uint256 constant STAKE_BASE_DAYS = 31;
    uint256 constant STAKE_BASE_PERIOD = 1 days;

    /// @notice Mapping to track nft locks
    mapping(uint256 => NFTLock) private locks;

    /// @notice NFTLocked event
    event NFTLocked(address indexed sender, uint256 tokenID, uint256 unlockTimestamp, uint256 tokenAmount);

    constructor(address tokenRewardAddress) {
        token = TokenReward(tokenRewardAddress);
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
    ) external returns (uint256 lockId) {
        _lockIds.increment();

        uint256 currentId = _lockIds.current();

        IERC721(source).safeTransferFrom(msg.sender, address(this), tokenId);

        // We need to transfer the NFT to our contract
        // (bool success, bytes memory data) = source.call(
        //     abi.encodeWithSignature("safeTransferFrom(address, address, uint256)", msg.sender, address(this), tokenId)
        // );

        // require(success, "Error while transferring NFT from source to staking contract");

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
        emit NFTLocked(msg.sender, tokenId, unlockTimestamp, tokenAmount);

        return currentId;
    }

    function unstake(uint256 lockId) external {
        NFTLock storage nftLock = locks[lockId];

        require(nftLock.source != address(0), "stake record not existing or already redeemed");
        require(nftLock.owner == msg.sender, "only stake owner can unstake");
        require(nftLock.unlockTimestamp < block.timestamp, "nft is still locked");

        address nftSource = nftLock.source;
        address nftOwner = nftLock.owner;
        uint256 nftTokenId = nftLock.tokenId;

        // reset the stake mapping
        delete locks[lockId];

        // Not checking that the msg.sender == owner because anyone could unstake it
        // The NFT will be anyway sent to the nftLock.owner

        IERC721(nftSource).safeTransferFrom(address(this), nftOwner, nftTokenId);
        // (bool success, ) = nftLock.source.call(
        //     abi.encodeWithSignature("safeTransferFrom(address, address, uint256)", address(this), nftOwner, nftTokenId)
        // );

        // require(success, "Error while transferring NFT from stake contract to prev owner");
    }
}
