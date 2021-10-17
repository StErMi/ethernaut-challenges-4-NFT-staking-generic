//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./TokenReward.sol";
import "base64-sol/base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

/**
 @title A contract to set a World Purpose
 @author Emanuele Ricci @StErMi
*/
contract GenericNFT is ERC721 {
    /// @notice utility
    using Strings for uint256;

    /// @notice utility
    using Counters for Counters.Counter;

    /// @notice utility to track NFT IDs
    Counters.Counter private _tokenId;

    /// @notice NFTLocked event
    event NFTLocked(address indexed sender, uint256 tokenID, uint256 unlockTimestamp, uint256 tokenAmount);

    constructor() ERC721("GenericNFT", "GNRNFT") {}

    /**
     @notice Mint a new NFT
     @return the NFT tokenId
    */
    function mint() public returns (uint256) {
        _tokenId.increment();

        uint256 current = _tokenId.current();

        _mint(msg.sender, current);
        return current;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "token does not exist");

        string[3] memory parts;
        parts[
            0
        ] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';

        parts[1] = "I'm a cool NFT!";

        parts[2] = "</text></svg>";

        string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2]));

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Item #',
                        tokenId.toString(),
                        '", "description": "NFTStaking allow you to stake your NFT for X months to get a TokenReward amount.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(abi.encodePacked("data:application/json;base64,", json));

        return output;
    }

    /**
     * @dev Returns true if this contract implements the interface defined by `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
