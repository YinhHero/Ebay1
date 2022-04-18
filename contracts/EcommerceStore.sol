pragma solidity ^ 0.5.16;

import './Escrow.sol';
contract EcommerceStore {
  enum ProductStatus {
    Open,
    Sold,
    Unsold
  }
  enum ProductCondition {
    New,
    Used
  }
  uint public productIndex;
  mapping(address => mapping(uint => Product)) stores;
  mapping(uint => address) productIdInStore;
  mapping(uint => address) productEscrow;
  struct Bid {
    address bidder;
    uint productId;
    uint value;
    bool revealed;
  }

  struct Product {
    uint id; //产品id
    string name; //产品名字
    string category; //分类
    string imageLink; //图片hash
    string descLink; //描述信息的hash
    uint auctionStartTime; //开始竞标的时间
    uint auctionEndTime; // 竞标结束时间
    uint startPrice; // 拍卖价格
    address highestBidder; // 赢家的钱包地址
    uint highestBid; // 赢家竞标的价格
    uint secondHighestBid; // 第二高的这个人的地址
    uint totalBids; // 一共有多少人参与竞标
    ProductStatus status; //状态
    ProductCondition condition; // 新、旧
    mapping(address => mapping(bytes32 => Bid)) bids;
  }

  constructor() public {
    productIndex = 0;
  }
  function numberOfItems() view public returns (uint){
    return productIndex;
  }
  event bidCast(address bidder, uint productId, uint value);
  function bid2() pure public returns (bool){
    // bidCast(msg.sender, 1, 2);
    return true;
  }

  event NewProduct(uint _productId, string _name, string _category, string _imageLink, string _descLink,
    uint _auctionStartTime, uint _auctionEndTime, uint _startPrice, uint _productCondition);

  /*  添加产品到区块链*/
  function addProductToStore(string memory _name, string memory _category, string memory _imageLink, string memory _descLink, uint _auctionStartTime, uint _auctionEndTime, uint _startPrice, uint _productCondition) public {
    require(_auctionStartTime < _auctionEndTime);
    productIndex += 1;
    Product memory product = Product(productIndex, _name, _category, _imageLink, _descLink, _auctionStartTime, _auctionEndTime, _startPrice, address(0), 0, 0, 0, ProductStatus.Open, ProductCondition(_productCondition));
    stores[msg.sender][productIndex] = product;
    productIdInStore[productIndex] = msg.sender;
  }
  /* 通过产品ID读取产品信息 */
  function getProduct(uint _productId) view public returns(uint, string memory , string memory , string memory , string memory , uint, uint, uint, ProductStatus, ProductCondition) {
    Product memory product = stores[productIdInStore[_productId]][_productId];
    return (product.id, product.name, product.category, product.imageLink, product.descLink, product.auctionStartTime, product.auctionEndTime, product.startPrice, product.status, product.condition);
  }


  function bid(uint _productId, bytes32 _bid) payable public returns(bool) {
    Product storage product = stores[productIdInStore[_productId]][_productId];
    require(now >= product.auctionStartTime);
    require(now <= product.auctionEndTime);
    require(msg.value > product.startPrice);
    require(product.bids[msg.sender][_bid].bidder == address(0));
    product.bids[msg.sender][_bid] = Bid(msg.sender, _productId, msg.value, false);
    product.totalBids += 1;
    return true;
  }

  function revealBid(uint _productId, string memory _amount, string memory _secret) public {
    Product storage product = stores[productIdInStore[_productId]][_productId];
    require(now > product.auctionEndTime);
    bytes32 sealedBid = sha256(abi.encodePacked(_amount, _secret));
    Bid memory bidInfo = product.bids[msg.sender][sealedBid];
    require(bidInfo.bidder > address(0)); //0xf55 uint160
    require(bidInfo.revealed == false);
    uint refund; // 退款
    uint amount = stringToUint(_amount);
    if (bidInfo.value < amount) { //mask  < actual
      refund = bidInfo.value;
    } else {
      if (address(product.highestBidder) == address(0)) {
        product.highestBidder = msg.sender;
        product.highestBid = amount;
        product.secondHighestBid = product.startPrice;
        refund = bidInfo.value - amount; // mask 20 actual 10.5
      } else {
        // 15  mask 25
        if (amount > product.highestBid) {
          product.secondHighestBid = product.highestBid;
          address(uint160(product.highestBidder)).transfer(product.highestBid);
          product.highestBidder = msg.sender;
          product.highestBid = amount; //15
          refund = bidInfo.value - amount; // 20 - 15
        } else if (amount > product.secondHighestBid) {
          // 13   18
          product.secondHighestBid = amount; //13
          refund = amount; //
        } else {
          refund = amount;
        }
      }
      if (refund > 0) {
        msg.sender.transfer(refund);
        product.bids[msg.sender][sealedBid].revealed = true;
      }
    }
  }

  function highestBidderInfo(uint _productId) view public returns(address, uint, uint) {
    Product memory product = stores[productIdInStore[_productId]][_productId];
    return (product.highestBidder, product.highestBid, product.secondHighestBid);
  }

  //查询当前产品投标人的数量
  function totalBids(uint _productId) view public returns(uint) {
    Product memory product = stores[productIdInStore[_productId]][_productId];
    return product.totalBids;
  }
 //将字符串转换为uint
  function stringToUint(string memory s) pure private returns(uint) {
    bytes memory b = bytes(s);
    uint result = 0;
    for (uint i = 0; i < b.length; i++) {
      if (uint8(b[i]) >= 48 && uint8(b[i]) <= 57) {
        result = result * 10 + (uint8(b[i]) - 48);
      }
    }
    return result;
  }

  function finalizeAuction(uint _productId) public {
    Product memory product = stores[productIdInStore[_productId]][_productId];

    require(now > product.auctionEndTime);
    require(product.status == ProductStatus.Open);
    require(product.highestBidder != msg.sender);
    require(productIdInStore[_productId] != msg.sender);

    if (product.totalBids == 0) {
      product.status = ProductStatus.Unsold;
    } else {

      Escrow escrow = (new Escrow).value(product.secondHighestBid)(_productId, product.highestBidder, productIdInStore[_productId], msg.sender);
      productEscrow[_productId] = address(escrow);
      product.status = ProductStatus.Sold;

      uint refund = product.highestBid - product.secondHighestBid;
      address(uint160(product.highestBidder)).transfer(refund);

    }
  }

  function escrowAddressForProduct(uint _productId) view public returns(address) {
    return productEscrow[_productId];
  }

  function escrowInfo(uint _productId) view public returns(address, address, address, bool, uint, uint) {
    return Escrow(productEscrow[_productId]).escrowInfo();
  }

  function releaseAmountToSeller(uint _productId) public {
    Escrow(productEscrow[_productId]).releaseAmountToSeller(msg.sender);
  }

  function refundAmountToBuyer(uint _productId) public {
    Escrow(productEscrow[_productId]).refundAmountToBuyer(msg.sender);
  }
}
