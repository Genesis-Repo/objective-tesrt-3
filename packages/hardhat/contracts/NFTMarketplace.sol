// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace is ERC721, Ownable {
    using SafeMath for uint256;

    struct NFT {
        uint256 tokenId;
        address owner;
        uint256 price;
        address highestBidder;
        uint256 highestBid;
        uint256 auctionEndTime;
        bool isListed;
    }

    mapping(uint256 => NFT) public nfts;
    uint256 public nftCount;

    event NFTListed(uint256 indexed tokenId, address indexed owner, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event AuctionStarted(uint256 indexed tokenId, address indexed owner, uint256 auctionEndTime);
    event NewBid(uint256 indexed tokenId, address indexed bidder, uint256 amount);
    event AuctionEnded(uint256 indexed tokenId, address indexed winner, uint256 amount);

    modifier onlyOwnerOf(uint256 _tokenId) {
        require(_exists(_tokenId), "Token ID does not exist");
        require(ownerOf(_tokenId) == msg.sender, "Not the owner of the token");
        _;
    }

    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(_price > 0, "Price must be greater than 0");
        require(ownerOf(_tokenId) == msg.sender, "You do not own this NFT");
        nfts[_tokenId] = NFT(_tokenId, msg.sender, _price, address(0), 0, 0, true);
        nftCount++;
        emit NFTListed(_tokenId, msg.sender, _price);
    }

    function startAuction(uint256 _tokenId, uint256 _duration) external onlyOwnerOf(_tokenId) {
        NFT storage nft = nfts[_tokenId];
        require(nft.isListed, "NFT is not listed for sale");
        
        nft.isListed = false;
        nft.auctionEndTime = block.timestamp + _duration;
        emit AuctionStarted(_tokenId, msg.sender, nft.auctionEndTime);
    }

    function placeBid(uint256 _tokenId) external payable {
        NFT storage nft = nfts[_tokenId];
        require(!nft.isListed, "Auction is not started");
        require(msg.sender != nft.owner, "Owner cannot place a bid");
        require(block.timestamp < nft.auctionEndTime, "Auction has ended");
        require(msg.value > nft.highestBid, "Bid must be higher than current highest bid");

        if (nft.highestBidder != address(0)) {
            payable(nft.highestBidder).transfer(nft.highestBid);
        }

        nft.highestBidder = msg.sender;
        nft.highestBid = msg.value;
        emit NewBid(_tokenId, msg.sender, msg.value);
    }

    function endAuction(uint256 _tokenId) external {
        NFT storage nft = nfts[_tokenId];
        require(!nft.isListed, "Auction is still active");
        require(block.timestamp >= nft.auctionEndTime, "Auction has not ended");

        address winner = nft.highestBidder;
        uint256 winningBid = nft.highestBid;
        
        nft.isListed = true;
        nft.owner = winner;
        nft.price = winningBid;
        nft.highestBidder = address(0);
        nft.highestBid = 0;
        nftCount--;

        payable(owner()).transfer(winningBid);
        emit AuctionEnded(_tokenId, winner, winningBid);
    }

    function withdrawBid(uint256 _tokenId) external {
        NFT storage nft = nfts[_tokenId];
        require(nft.highestBidder == msg.sender, "You are not the highest bidder");
        
        uint256 amount = nft.highestBid;
        nft.highestBid = 0;
        nft.highestBidder = address(0);

        payable(msg.sender).transfer(amount);
    }

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

}