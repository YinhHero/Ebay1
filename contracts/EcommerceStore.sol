pragma solidity ^ 0.5.16;

import './Escrow.sol';
contract EcommerceStore {
  uint public productIndex;
  uint public totalDeposit;   //总共收入押金
  constructor() public {
    productIndex = 0;
    totalDeposit = 0;
  }
  //1.  定义商品结构
  // 2. 添加商品函数
  // 3. 根据id获取商品函数
  struct Product {
    //第一部分：基本信息
    uint id; //产品id:每添加一个，id自动加一
    string name; //产品名字
    string category; //分类
    string imageLink; //图片hash
    string descLink; //描述信息的hash
    // 起拍价格，竞拍价格不小于起拍价格
    // 起拍时间
    // 竞拍阶段结束时间
    // 产品竞拍状态：Open，sold，unsold
    // 产品的情况：新，旧
    uint auctionStartTime; //开始竞标的时间
    uint auctionEndTime; // 竞标结束时间
    uint startPrice; // 拍卖价格
    ProductStatus status; //状态
    ProductCondition condition; // 新、旧
    //第二部分：竞标信息
    uint totalBids; // 一共有多少人参与竞标
    //一个商品，所有人都可以竞标，并且，同一个人可以多次竞标
    //Byes32是理想价格与密文生成的的哈希值
    mapping(address => mapping(bytes32 => Bid)) bids;
    //第三部分：揭标信息
    address highestBidder; // 最高出价人
    uint highestBid; // 最高出价
    uint secondHighestBid; // 第二高出价
  }

  enum ProductStatus {Open,Sold,Unsold}
  enum ProductCondition {New,Used}

  //定义一个存储所有商品的结构 stores
  mapping(address => mapping(uint => Product)) stores;
  //定义一个存储商品与卖家对应结构
  mapping(uint => address) productIdToOwner;

  /*  添加产品到区块链*/
  function addProductToStore(string memory _name, string memory _category, string memory _imageLink, string memory _descLink, uint _startTime, uint _endTime, uint _startPrice, uint condition) payable public {
    require(_startTime < _endTime);
    productIndex += 1;
    Product memory product = Product({
      id : productIndex,
      name : _name,
      category : _category,
      imageLink : _imageLink,
      descLink : _descLink,
      startPrice : _startPrice,
      auctionStartTime : _startTime,
      auctionEndTime : _endTime,
      status : ProductStatus.Open,
      condition : ProductCondition(condition),
      highestBid : 0,
      highestBidder : address(0),
      secondHighestBid : 0,
      totalBids : 0
    });
    stores[msg.sender][productIndex] = product;
    productIdToOwner[productIndex] = msg.sender;
    totalDeposit += _startPrice;
  }

  //通过产品ID获取产品上传者地址
  function getAccountOfId(uint _productId) public view returns(address){
    return productIdToOwner[_productId];
  }

  function testHash(uint value, string memory secret) public pure returns (bytes32) {
      bytes memory bytesInfo = abi.encodePacked(value, secret);
      bytes32 bytesHash = sha256(bytesInfo);
      return bytesHash;
  }

  // 竞标的结构：
    // 	1. 产品ID
    // 	2. 转账（迷惑）价格，注意，不是理想价格
    // 	3. 揭标与否
    // 	4. 竞标人
  struct Bid {
    uint productId;
    uint price;  //msg.value
    bool isRevealed;
    address bidder;
  }

  // 竞标函数：
  //正常是传理想价格和密文的哈希过来，为了简化，先直接传过来，方便测试
  // 1. 创建一个竞标（产品id，理想价格，密文）
  // 2. 找到Product，将竞标放入bids结构中
  // mapping(address => mapping(bytes32 => Bid)) bids;
  function bid(uint _productId, bytes32 _bytesHash) payable public {
    Product storage product = stores[productIdToOwner[_productId]][_productId];
    require(now >= product.auctionStartTime);
    require(now <= product.auctionEndTime);
    require(msg.value > product.startPrice);
    require(product.bids[msg.sender][_bytesHash].bidder == address(0));
    product.bids[msg.sender][_bytesHash] = Bid(_productId, msg.value, false, msg.sender);
    product.totalBids ++;
  }

  //返回某一个竞标的详情
  function getBidById(uint _productId, uint _idealPrice, string memory _secret) public view returns (uint, uint, bool, address) {
    Product storage product = stores[productIdToOwner[_productId]][_productId];
    bytes memory bytesInfo = abi.encodePacked(_idealPrice, _secret);
    bytes32 bytesHash = keccak256(bytesInfo);
    Bid memory bidLocal = product.bids[msg.sender][bytesHash];
    return (bidLocal.productId, bidLocal.price, bidLocal.isRevealed, bidLocal.bidder);
  }

  event revealEvent(uint productid, bytes32 bidId, uint idealPrice, uint price, uint refund);

  function numberOfItems() view public returns (uint){
    return productIndex;
  }

  event NewProduct(uint _productId, string _name, string _category, string _imageLink, string _descLink,
    uint _auctionStartTime, uint _auctionEndTime, uint _startPrice, uint _productCondition);

  function revealBid(uint _productId, uint _idealPrice, string memory _secret) public {
    Product storage product = stores[productIdToOwner[_productId]][_productId];
    require(now > product.auctionEndTime);
    bytes32 bidId = sha256(abi.encodePacked(_idealPrice, _secret));
    //一个人可以对同一个商品竞标多次，揭标的时候也要揭标多次, storage类型
    Bid storage currBid = product.bids[msg.sender][bidId];
    require(currBid.bidder > address(0)); //0xf55 uint160
    require(!currBid.isRevealed);
    //说明找到了这个标
    currBid.isRevealed = true;
    //bid中的是迷惑价格，真实价格揭标时传递进来
    uint confusePrice = currBid.price;
    uint refund = 0; // 退款
    uint idealPrice = _idealPrice;
    if (confusePrice < idealPrice) {
      //路径1：无效交易
      refund = confusePrice;
    } else {
      if (idealPrice > product.highestBid) {
        if (product.highestBidder == address(0)) {
          //当前账户是第一个揭标人
          //路径2：
          product.highestBidder = msg.sender;
          product.highestBid = idealPrice;
          product.secondHighestBid = product.startPrice;
          refund = confusePrice - idealPrice;
        } else {
          //路径3：不是第一个，但是出价是目前最高的，更新最高竞标人，最高价格，次高价格
          address(uint160(product.highestBidder)).transfer(product.highestBid);
          product.secondHighestBid = product.highestBid;
          product.highestBid = idealPrice;
          product.highestBidder = msg.sender;
          refund = confusePrice - idealPrice;
        }
      } else {
        //路径4：价格低于最高价，但是高于次高价
        if (idealPrice > product.secondHighestBid) {
          //路径4：更新次高价，然后拿回自己的钱
          product.secondHighestBid = idealPrice;
        } else {
          //路径5：路人甲，价格低于次高价，直接退款
          refund = confusePrice;
        }
      }
    }
    emit revealEvent(_productId, bidId, confusePrice, currBid.price, refund);
    if (refund > 0) {
      msg.sender.transfer(refund);
    }
  }

  //通过产品ID获取产品最高出价信息、
  function getHighestBidInfo(uint _productId) view public returns(address, uint, uint, uint) {
    address owner = productIdToOwner[_productId];
    Product memory product = stores[owner][_productId];
    return (product.highestBidder, product.highestBid, product.secondHighestBid, product.totalBids);
  }

  /* 通过产品ID读取产品信息 */
  function getProductById(uint _productId) view public returns(uint, string memory , string memory , string memory , string memory , uint, uint, uint, uint, address,uint) {
    address owner = productIdToOwner[_productId];
    Product memory product = stores[owner][_productId];
    return (product.id, product.name, product.category, product.imageLink, product.descLink, product.auctionStartTime, product.auctionEndTime, product.startPrice, uint(product.status), product.highestBidder, product.highestBid);
  }

  //key是产品id，value：是第三方合约
  mapping(uint => address) public productToEscrow;

  //查询当前产品投标人的数量
  function totalBids(uint _productId) view public returns(uint) {
    address owner = productIdToOwner[_productId];
    Product memory product = stores[owner][_productId];
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

  //仲裁
  function finalizeAuction(uint _productId) public {
    address owner = productIdToOwner[_productId];
    Product storage product = stores[owner][_productId];
    address buyer = product.highestBidder;
    address seller = owner;
    address arbiter = msg.sender;
    require(now > product.auctionEndTime);
    require(buyer != msg.sender);
    require(seller != msg.sender);
    require(product.status == ProductStatus.Open);
    if (product.totalBids == 0) {
      product.status = ProductStatus.Unsold;
    } else {
      product.status = ProductStatus.Sold;
    }
    Escrow escrow = (new Escrow).value(product.secondHighestBid)(buyer, seller, arbiter);
    productToEscrow[_productId] = address(escrow);
    //退还差价 30- 20 = 10 ， 30是理想出价，20是次高
    uint refund = product.highestBid - product.secondHighestBid;
    address(uint160(buyer)).transfer(refund);
  }

  function escrowAddressForProduct(uint _productId) view public returns(address) {
    return productToEscrow[_productId];
  }

  function getEscrowInfo(uint _productId) view public returns(address, address, address, bool, uint, uint) {
    address escrow = productToEscrow[_productId];
    return Escrow(escrow).escrowInfo();
  }

  function releaseAmountToSeller(uint _productId) payable public {
    address escrow = productToEscrow[_productId];
    Escrow(escrow).releaseAmountToSeller(msg.sender);
    if(escrow.balance == 0){
      refundDeposit(_productId);
    }
  }

  function refundAmountToBuyer(uint _productId) payable public {
    address escrow = productToEscrow[_productId];
    Escrow(escrow).refundAmountToBuyer(msg.sender);
    if(escrow.balance == 0){
      refundDeposit(_productId);
    }
  }

  function refundDeposit(uint _productId) payable public {
    address seller = productIdToOwner[_productId];
    Product memory product = stores[seller][_productId];
    totalDeposit -= product.startPrice;
    address(uint160(seller)).transfer(product.startPrice);
  }
}
