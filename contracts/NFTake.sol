//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
// TODO audit
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract NFTake is Ownable, ERC721URIStorage {
    // Place NFT for borrowing  
    event BidPlaced(address indexed _owner, uint256 indexed _id, uint256 _price);
    // Emitted when placed bid was bought 
    // event AssetBorrowed(address indexed _owner, address indexed _borrower, uint256 indexed _id, uint256 _from, 
    //                     uint256 _to, uint256 _collateralAmount, uint256 _paymentAmount);
    event SubscriptionPurchased(address indexed who, uint256 purchasePrice, uint256 fromTs, uint256 toTs, uint8 _subscriptionType);
    event TokenAcquired(address sender, address receiver, uint256 tokenId, uint256 userLeftActions, uint256 poolId);

    // event BidPlaced(address indexed _from, uint256 indexed _id, uint256 _collateralAmount, uint256 _paymentAmount);
    // event BidPlaced(address indexed _from, uint256 indexed _id, uint256 _collateralAmount, uint256 _paymentAmount);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Any internal ERC20 used for payments
    IERC20 public immutable testDAI = IERC20(0xc3dbf84Abb494ce5199D5d4D815b10EC29529ff8);

    struct BorrowedAsset {
        uint256 fromTs;
        uint256 toTs;
        address borrower;
        // TODO (ERC20) asset addr
        uint256 collateralAmount;
        // TODO same
        uint256 paymentAmount;
    }

    // User can have multiple borrows
    mapping (bytes32 => mapping (uint256 => BorrowedAsset)) borrowInfo;
    // Info for each token
    mapping (uint256 => AssetInternalStatus) tokenStatus;

    enum AssetInternalStatus {
        Free,
        Taken,
        Frozen
    }

    // TODO Pool contract 
    uint256 public maxTakeAmount; // Amount of NFT that can be acquired in one era
    uint256 public maxUploadAmount; // Amount of NFTs that can be minted for one contributor
    uint256 public buyerSubscriptionPrice; // Price for entering pool as Buyer
    uint256 public contributorSubscriptionPrice;    // Price for entering pool as contributor
    uint256 public buyerMaxActions;
    uint256 public contributorMaxActions;
    uint256 public poolId = 1; 
    mapping (address => SubscriptionInfo) contributorsInfo;
    mapping (address => SubscriptionInfo) buyersInfo;

    struct SubscriptionInfo {
        uint256 fromTs;
        uint256 toTs;
        uint256 actionsLeft;
    }

    // TODO Controller contract
    // two bits for each possible pool 
    // 01 => can purchase can't upload 
    // 10 => can upload can't purchase 
    mapping (address => uint256) subscribedUsersType;
    // TODO use bitmask
    enum SubscriptionType {
        Buyer,
        Contributor,
        Both
    }

    struct Bid {
        address owner;
    }

    // tokenId => Bid / None
    mapping (uint256 => Bid) totalBids;
    // tokenId => status
    mapping (uint256 => AssetInternalStatus) assetStatus;

    function placeBid(uint256 tokenId, uint256 price) public {
        require(price != 0, "Supplied price below minimal boundary");
        require(is_contributor_active(msg.sender), "Your subscription is expired");
        require(msg.sender == ownerOf(tokenId), "You are not allowed to sell this token");
        require(totalBids[tokenId].owner == address(0), "NFT already being sold");
        // require(_tokenApprovals[tokenId] == address(this), "You should approve this contract to pull the NFT");
        totalBids[tokenId] = Bid({owner: msg.sender});
        // TODO Lock this NFT at owner's account
        emit BidPlaced(msg.sender, tokenId, price);
    }

    function claim_bid_by_tokenId(uint256 tokenId) public {
        require(is_buyer_active(msg.sender),  "Your subscription is expired");
        require(totalBids[tokenId].owner == address(0), "Bid for this token is not placed");
        uint256 userLeftActions = buyersInfo[msg.sender].actionsLeft;
        require(userLeftActions > 0, "You have exceed your actions limit for this era");
        buyersInfo[msg.sender].actionsLeft = userLeftActions - 1;
        // TODO more sanity checks
        
        _transfer(totalBids[tokenId].owner,  msg.sender, tokenId);
        // We remove this bid on success
        emit TokenAcquired(totalBids[tokenId].owner, msg.sender, tokenId, buyersInfo[msg.sender].actionsLeft, poolId);
        totalBids[tokenId].owner = address(0);
    }

    // TODO Move to pool? Split maybe?
    function buy_subscription_type(uint256 poolId, uint8 _subscriptionType, uint256 deltaTs) public {
        // TODO consider lowest deltaTs
        require(deltaTs != 0, "You can't buy subscription for 0 time!");
        // TODO pool counter 
        require(poolId == 1, "Wrong pool supplied");
        // Wrap enum inside for easier rpc interaction
        SubscriptionType subscriptionType = SubscriptionType(_subscriptionType);

        // TODO check bitmask inside if input bit already set
        uint256 _existingSubType = subscribedUsersType[msg.sender];
        SubscriptionType existingSubType = extractSubTypeFromBitmaskByPool(poolId, _existingSubType);
        require(subscriptionType != existingSubType, "You already have that subscription!");
        
        uint256 fromTs = block.timestamp;
        uint256 toTs = fromTs + deltaTs;

        uint256 purchasePrice;

        // TODO handle existing subscription?
        if (subscriptionType == SubscriptionType.Buyer) {
            purchasePrice = buyerSubscriptionPrice;
            buyersInfo[msg.sender] = SubscriptionInfo ({fromTs: fromTs, toTs: toTs, actionsLeft: buyerMaxActions});
        } else if (subscriptionType == SubscriptionType.Contributor) {
            purchasePrice = contributorSubscriptionPrice;
            contributorsInfo[msg.sender] = SubscriptionInfo ({ fromTs: fromTs, toTs: toTs, actionsLeft: contributorMaxActions});
        } else {
            purchasePrice = contributorSubscriptionPrice + buyerSubscriptionPrice;
            contributorsInfo[msg.sender] = SubscriptionInfo ({ fromTs: fromTs, toTs: toTs, actionsLeft: contributorMaxActions });
            buyersInfo[msg.sender] = SubscriptionInfo ({fromTs: fromTs, toTs: toTs, actionsLeft: buyerMaxActions});
        }

        check_and_transfer(msg.sender, purchasePrice * deltaTs);
        emit SubscriptionPurchased(msg.sender, purchasePrice, fromTs, toTs, _subscriptionType);
    } 


    // Helper shit
    function check_and_transfer(address user, uint256 amount) internal {
            require(testDAI.allowance(user, address(this)) >= amount,
                "You must approve more tokens to contract for this subscription!");
            
            testDAI.transferFrom(msg.sender, address(this), amount);
    }
    // TODO write true bitmask handling 
    function setMarket(uint256 poolNumber, SubscriptionType subType) internal {

    }

    // TODO Write true bitmask handling
    function extractSubTypeFromBitmaskByPool(uint256 poolId, uint256 bitmask) internal view returns (SubscriptionType) {
        require(bitmask <= 3 && bitmask != 0, "Unsupported pool!");
        
        if (bitmask == 1) {
            return SubscriptionType.Buyer;
        } else if (bitmask == 2) {
            return SubscriptionType.Contributor;
        } else {
            return SubscriptionType.Both;
        }   
    }

    function is_contributor_active(address contributor) public view returns (bool) {
        SubscriptionType subType = extractSubTypeFromBitmaskByPool(1, subscribedUsersType[msg.sender]);
        require(subType == SubscriptionType.Contributor || subType == SubscriptionType.Both, "You are not registered as a contributor!");
        uint256 currentTs = block.timestamp;
        SubscriptionInfo memory subTime = contributorsInfo[contributor];
        return currentTs > subTime.fromTs && currentTs < subTime.toTs;
    }

    function is_buyer_active(address buyer) public view returns (bool) {
        SubscriptionType subType = extractSubTypeFromBitmaskByPool(1, subscribedUsersType[msg.sender]);
        require(subType == SubscriptionType.Buyer || subType == SubscriptionType.Both, "You are not registered as a buyer!");
        uint256 currentTs = block.timestamp;
        SubscriptionInfo memory subTime = buyersInfo[buyer];
        return currentTs > subTime.fromTs && currentTs < subTime.toTs;
    }
    
    // NOTE
    // X TODO make transfer to different domains
    // V TODO index by hash of domain name

    // TODO? modifier onlyContributor {
    //     // TODO Modifier for contributors (people who submit crypto-assets)
    // }

    // TODO what we need to setup?
    constructor() 
    ERC721("NFTake", "TKE") {
        // withdrawPeriod = _withdrawPeriod;
        console.log("Deploying a NFTake contract");
    }

    // Anyone can register NFT, and get into contributor's list
    function mintNFT(address recipient, string memory tokenURI)
        public 
        // onlyContributor
        returns (uint256)
    {
        require(is_contributor_active(msg.sender), "You are not allowed to mint NFT!");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        assetStatus[newItemId] = AssetInternalStatus.Free;
        return newItemId;
    }

    // function buy

    // Contributor can place his asset for sale, set (base approve amount), (full price) and more ?     
    // function placeBid(uint256 tokenId, uint256 _collateralAmount, uint256 _paymentAmount) public {
    //     // TODO audit this call
    //     require(_isApprovedOrOwner(msg.sender, tokenId), "msg.sender not permitted to access this asset");
    //     // require token not already bidded or sold
    //     // require(totalBids[msg.sender][tokenId].basePrice == 0, "You already placed your bid!");
    //     // require(borrowInfo[msg.sender][tokenId].fromTs == 0, "This NFT was already borrowed!");
    //     require(assetStatus[tokenId] == AssetInternalStatus.Free, "This asset is already used / not initialized");
    //     require(_collateralAmount != 0 && _paymentAmount != 0, "Invalid bid position, zero amounts supplied");

    //     // TODO What else do we need?
    //     totalBids[tokenId] = Bid ({
    //             owner: msg.sender,
    //             collateralAmount: _collateralAmount,
    //             paymentAmount: _paymentAmount
    //     });

    //     assetStatus[tokenId] = AssetInternalStatus.BidPlaced;
    //     emit BidPlaced(msg.sender, tokenId, _collateralAmount, _paymentAmount); 
    // } 

    // TODO really consider auction here if enough time left
    // toTs - for what amount of time, identifier - for whom
    // function buyByTokenId(uint256 tokenId, uint256 _toTs, bytes32 identifier) public {
    //     require(assetStatus[tokenId] == AssetInternalStatus.BidPlaced, "NFT is not for sale!");
    //     Bid memory _bid = totalBids[tokenId]; 
    //     require(_bid.collateralAmount != 0, "Bid does not exist");
    //     uint256 totalPayment = _bid.collateralAmount + _bid.paymentAmount;

    //     require(testDAI.allowance(msg.sender, address(this)) >= totalPayment,
    //          "You must approve your DAI to contract for this bid!");
        
    //     testDAI.transferFrom(msg.sender, address(this), totalPayment);

    //     // TODO check identifier existance, consider safety

    //     uint256 _fromTs = block.timestamp;
    //     // create entry in borrows mapping
    //     borrowInfo[identifier][tokenId] = BorrowedAsset ({
    //         fromTs: _fromTs,
    //         toTs: _toTs,
    //         borrower: msg.sender,
    //         collateralAmount: _bid.collateralAmount,
    //         paymentAmount: _bid.paymentAmount
    //     });

    //     assetStatus[tokenId] == AssetInternalStatus.Borrowed;
    //     delete totalBids[tokenId];
    //     emit AssetBorrowed(_bid.owner, msg.sender, tokenId, _fromTs, _toTs, _bid.collateralAmount, _bid.paymentAmount);
    // }


    // function check_asset_status(uint256 tokenId) 
    // public view returns (AssetInternalStatus) {
    //     // TODO check if borrowskeccak(domain)
    //     // TODO this shall return something more useful)
    //     return assetStatus[tokenId];
    // }

    // // User can pay back? no way
    // function return_borrow(uint256 tokenId) public {
    //     require(assetStatus[tokenId] == AssetInternalStatus.Borrowed, "Asset in not borrowed!");

    // }
    // // Borrower can extend time for borrow
    // function extend_borrow_by() public {

    // }
    // // function liquidation(address borrower, ) public {

    // // }
    // // TODO ? NFT Owner may be able to recall asset he lended
    // function recall_borrow() public {

    // }

    // function recall_bid() public {

    // }

    // TODO later consider PoS or something?
    // function setWithdrawPeriod(uint256 _withdrawPeriod) public onlyOwner {
    //     // TODO require some boundaries
    //     withdrawPeriod = _withdrawPeriod;
    // }
}
