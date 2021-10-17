# Ethernaut challenges

![amir-zand-thumb1](https://user-images.githubusercontent.com/550409/136199654-67467daa-fd9a-4f6a-9c07-969626d5ae53.jpg)

Image by [Amir Zand](https://www.artstation.com/amirzand)

This repository contains the solution of the [Ethernaut Challenge 4 - NFT staking](https://github.com/ethernautdao/challenges).
This is a variation of the [previous challenge implementation](https://github.com/StErMi/ethernaut-challenges-4-NFT-staking). This implementation support a general-purpose version of NFT staking.

With the NFTStaking contract you can stake NFT from any ERC721 compliant contract.

## Doubts and questions to be answered

There are still some question that I need to find an answer from both **security** and **performance** point of view.

### use `call` or direct `IERC721` function?

In this case I have two options to stake/unstake the NFT

**Option 1:** call the `safeTransferFrom` function directly from the contract implementation

`IERC721(source).safeTransferFrom(msg.sender, address(this), tokenId);`

**Option 2:** use a the `call` low-level function

```ts
(bool success, bytes memory data) = source.call(
    abi.encodeWithSignature("safeTransferFrom(address, address, uint256)", msg.sender, address(this), tokenId)
);
require(success, "Error while transferring NFT from source to staking contract");
```

both of these solution achieve the same result but I would like to know which is the best solution from a security propsective.

This implementation also throw another question: what if the `source` is not an `ERC721` contract, does not implement the `safeTransferFrom` function? In this case the `fallback` function of source will be called, what could a malicious contract do in this case?

### Is there a better way to store `locks`?

Is there a way to store the locks mapping with a different key that can include both the source address and the tokenID in order to create a composed key?

## Challenge 4 - NFT staking

_Difficulty_

- Solidity: Easy
- dApp: n/a

_Objectives_

- Build an NFT Staking contract that will reward the users with a custom ERC20 token based on their staking period that they choose
- Example: I can stake my NFT for 1 month and I get a reward of X%, I stake it for 6 months and i get a reward of 2X% and so on.
- The NFTs that are used for the staking must be also present into a custom OpenSea collection
- Full unit test coverage

_Hints_

- Use hardhat for unit testing
- Use Rinkeby for OpenSea testnet
