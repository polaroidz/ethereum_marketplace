pragma solidity ^0.4.4;

import "./TokenIssuer.sol";

contract Marketplace is TokenIssuer {

  struct Product {
    uint id;
    address owner;
    string name;
    uint256 unitPrice;
  }

  struct Offer {
    uint id;
    uint productId;
    address seller;
    uint256 proposedUnitPrice;
    uint quantity;
  }

  struct OfferBid {
    uint id;
    uint offerId;
    address bider;
    uint256 proposedUnitPrice;
    uint quantity;
  }

  struct Order {
    uint id;
    uint offerId;
    address seller;
    address buyer;
    uint256 agreedUnitPrice;
    uint quantity;
  }

  uint public lastProductId = 0;
  uint public lastOfferId = 0;
  uint public lastOfferBidId = 0;
  uint public lastOrderId = 0;

  Product[] public products;
  Offer[] public offers;
  OfferBid[] public offersBid;
  Order[] public orders;

  event ProductRegistered(uint id);
  event OfferRegistered(uint id);
  event OfferBidRegistered(uint id);
  event OrderRegistered(uint id);

  function Marketplace() onlyOwner public {
    //
  }

  function registerProductFrom(address owner, string name, uint256 unitPrice) public returns (uint) {
    Product storage product = products[products.length];

    product.id = lastProductId++;
    product.owner = owner;
    product.name = name;
    product.unitPrice = unitPrice;

    emit ProductRegistered(product.id);

    return product.id;
  }

  function registerOfferFrom(address seller, uint productId, uint256 proposedUnitPrice, uint quantity) public returns (uint) {
    require(productId <= products.length);
    
    Product memory product = products[productId];

    require(product.owner == seller);

    Offer storage offer = offers[offers.length];

    offer.id = lastOfferId++;
    offer.productId = productId;
    offer.seller = seller;
    offer.proposedUnitPrice = proposedUnitPrice;
    offer.quantity = quantity;

    emit OfferRegistered(offer.id);

    return offer.id;
  }

  function registerOfferBidFrom(address bider, uint256 proposedUnitPrice, uint quantity) public returns (uint) {

  }

  function registerOrderFrom(address buyer, uint offerId, uint agreedUnitPrice, uint quantity) public returns (uint) {
    require(offerId <= offers.length);

    Offer memory offer = offers[offerId];

    Order storage order = orders[orders.length];

    order.id = lastOrderId++;
    order.offerId = offerId;
    order.buyer = buyer;
    order.seller = offer.seller;
    order.agreedUnitPrice = agreedUnitPrice;
    order.quantity = quantity;

    emit OrderRegistered(order.id);

    return order.id;
  }

}
