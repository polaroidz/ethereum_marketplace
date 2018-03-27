pragma solidity ^0.4.4;

import "./TokenIssuer.sol";

contract Marketplace is TokenIssuer {

  struct Product {
    uint id;
    address owner;
    string name;
    uint256 unitPrice;
    uint timestamp;
  }

  struct Offer {
    uint id;
    uint productId;
    address seller;
    uint256 proposedUnitPrice;
    uint quantity;
    uint timestamp;
  }

  struct OfferBid {
    uint id;
    uint offerId;
    address bider;
    uint256 proposedUnitPrice;
    uint quantity;
    uint timestamp;
  }

  struct Order {
    uint id;
    uint offerBidId;
    uint offerId;
    address seller;
    address buyer;
    uint256 agreedUnitPrice;
    uint quantity;
    uint timestamp;
  }

  struct OrderCourierBid {
    uint id;
    uint orderId;
    address courier;
    uint256 price;
    uint timestamp;
  }

  uint public lastProductId = 0;
  uint public lastOfferId = 0;
  uint public lastOfferBidId = 0;
  uint public lastOrderId = 0;
  uint public lastOrderCourierBidId = 0; 

  Product[] public products;
  Offer[] public offers;
  OfferBid[] public offersBid;
  Order[] public orders;
  OrderCourierBid[] public orderCourierBids[];

  event ProductRegistered(uint id);
  event OfferRegistered(uint id);
  event OfferBidRegistered(uint id, uint256 totalValue);
  event OrderRegistered(uint id, uint256 totalValue);
  event OrderCourierBidRegistered(uint id, address courier, uint256 price);

  event OfferBidRefused(uint id);

  event OrderCourierBidRefused(uint id);

  mapping (uint => bool) public isOfferStanding;

  mapping (uint => uint) public offerAvailableQuantity;

  mapping (uint => bool) public isOfferBidAccepted;
  mapping (uint => bool) public isOfferBidRefused;

  mapping (address => uint256) public tokensAtStake;

  mapping (uint => bool) public orderHasCourier;

  mapping (uint => bool) public orderCourierBidAcceptedBySeller;
  mapping (uint => bool) public orderCourierBidAcceptedByBuyer;

  mapping (uint => bool) public orderCourierBidRefused;

  function Marketplace() onlyOwner public {
    //
  }

  function registerProductFrom(address owner, string name, uint256 unitPrice) public returns (uint) {
    require(!isAccountFrozen[owner]);
    require(unitPrice > 0);

    Product storage product = products[products.length];

    product.id = lastProductId++;
    product.owner = owner;
    product.name = name;
    product.unitPrice = unitPrice;
    product.timestamp = block.timestamp;

    emit ProductRegistered(product.id);

    return product.id;
  }

  function registerOfferFrom(address seller, uint productId, uint256 proposedUnitPrice, uint quantity) public returns (uint) {
    require(!isAccountFrozen[seller]);
    require(productId <= products.length);
    
    Product memory product = products[productId];

    require(product.owner == seller);

    Offer storage offer = offers[offers.length];

    offer.id = lastOfferId++;
    offer.productId = productId;
    offer.seller = seller;
    offer.proposedUnitPrice = proposedUnitPrice;
    offer.quantity = quantity;
    offer.timestamp = block.timestamp;

    offerAvailableQuantity[offer.id] = quantity;
    isOfferStanding[offer.id] = true;

    emit OfferRegistered(offer.id);

    return offer.id;
  }

  function registerOfferBidFrom(address bider, uint offerId, uint256 proposedUnitPrice, uint quantity) onlyOwner public returns (uint) {
    require(offerId <= offers.length);
    require(isOfferStanding[offerId]);

    Offer memory offer = offers[offerId];

    require(bider != offer.seller);

    require(proposedUnitPrice > 0);
    require(proposedUnitPrice <= offer.proposedUnitPrice);

    require(quantity > 0);
    require(quantity <= offerAvailableQuantity[offerId]);

    uint256 totalValue = proposedUnitPrice * quantity;

    require(balanceOf[bider] >= totalValue);

    // Bider puts its money on stake so it cant start bidding withou the funds for it
    balanceOf[bider] -= totalValue;
    balanceOf[owner] += totalValue;

    tokensAtStake[bider] += totalValue; 

    OfferBid storage offerBid = offersBid[offersBid.length];

    offerBid.id = lastOfferBidId++;
    offerBid.bider = bider;
    offerBid.offerId = offerId;
    offerBid.proposedUnitPrice = proposedUnitPrice;
    offerBid.quantity = quantity;
    offerBid.timestamp = block.timestamp;

    offerAvailableQuantity[offerId] -= quantity;

    isOfferBidRefused[offerBid.id] = false;
    isOfferBidAccepted[offerBid.id] = false;

    emit OfferBidRegistered(offerBid.id, totalValue);

    return offerBid.id;
  }

  function refuseOfferBid(uint offerBidId) onlyOwner public returns (bool) {
    require(offerBidId <= offersBid.length);

    require(!isOfferBidRefused[offerBidId]);
    require(!isOfferBidAccepted[offerBidId]);

    OfferBid memory offerBid = offersBid[offerBidId];

    uint256 totalValue = offerBid.proposedUnitPrice * offerBid.quantity;

    balanceOf[owner] -= totalValue;
    balanceOf[offerBid.bider] += totalValue;

    tokensAtStake[offerBid.bider] -= totalValue;

    isOfferBidRefused[offerBidId] = true;

    offerAvailableQuantity[offerBid.offerId] += offerBid.quantity;

    emit OfferBidRefused(offerBidId);

    return true;
  }

  function acceptOfferBid(uint offerBidId) onlyOwner public returns (uint) {
    require(offerBidId <= offersBid.length);
    
    require(!isOfferBidRefused[offerBidId]);
    require(!isOfferBidAccepted[offerBidId]);

    OfferBid memory offerBid = offersBid[offerBidId];
    Offer memory offer = offers[offerBid.offerId];

    require(offerAvailableQuantity[offer.id] >= offerBid.quantity);

    isOfferBidAccepted[offerBidId] = true;

    Order memory order = orders[orders.length];

    order.id = lastOrderId++;
    order.offerBidId = offerBid.id;
    order.offerId = offer.id;
    order.buyer = offerBid.bider;
    order.seller = offer.seller;
    order.agreedUnitPrice = offerBid.proposedUnitPrice;
    order.quantity = offerBid.quantity;
    order.timestamp = block.timestamp;

    uint256 totalValue = order.agreedUnitPrice * order.quantity;

    tokensAtStake[order.buyer] -= totalValue;

    emit OrderRegistered(order.id, totalValue);

    orderHasCourier[order.id] = false;

    return order.id;
  }

  function registerOrderCourierBid(uint orderId, address courier, uint256 price) onlyOwner public returns (uint) {
    require(orderId <= orders.length);

    require(price > 0);

    require(balanceOf[courier] >= price);

    Order memory order = orders[orderId];

    require(courier != order.buyer);
    require(courier != order.seller);

    OrderCourierBid storage orderCourierBid = orderCourierBids[orderCourierBids.length];

    orderCourierBid.id = lastOrderCourierBidId++;
    orderCourierBid.orderId = orderId;
    orderCourierBid.courier = courier;
    orderCourierBid.price = price;
    orderCourierBid.timestamp = block.timestamp;

    balanceOf[courier] -= price;
    balanceOf[owner] += price;

    tokensAtStake[courier] += price;

    OrderCourierBidRegistered(orderCourierBid.id, courier, price);

    orderCourierBidAcceptedBySeller[orderCourierBid.id] = false;
    orderCourierBidAcceptedByBuyer[orderCourierBid.id] = false;

    orderCourierBidRefused[orderCourierBid.id] = false;

    return orderCourierBid.id;
  }

  function refuseOrderCourierBid(uint orderCourierBidId) onlyOwner public returns (bool) {
    require(orderCourierBidId <= orderCourierBids.length);

    require(!orderCourierBidAcceptedBySeller[orderCourierId] && !orderCourierBidAcceptedByBuyer[orderCourierId]);

    OrderCourierBid memory orderCourierBid = orderCourierBids[orderCourierBidId]; 

    orderCourierBidRefused[orderCourierBid.id] = true;

    balanceOf[orderCourierBid.courier] += orderCourierBid.price;
    balanceOf[owner] -= orderCourierBid.price;

    tokensAtStake[orderCourierBid.courier] += orderCourierBid.price;

    OrderCourierBidRefused(orderCourierBid.id);

    return true;
  }
}
