pragma solidity ^0.4.4;

import "./DAO.sol";

// Contrato que define o funcionamento do marketplace na
// plataforma.
contract Marketplace is DAO {

  // Estrutura responsável por armazenar dados dos produtos
  // cadastrados.
  struct Product {
    uint id;
    address owner;
    string name;
    uint256 unitPrice;
    uint timestamp;
  }

  // Estrutura responsável por armazenar dados das ofertas
  // criadas pelos vendedores em cima dos produtos cadastrados
  // por eles. A oferta é iniciada com um valor de unidade
  // proposto, porém esse valor pode ser mudado durante o 
  // leilão realizado em cima da mesma.
  struct Offer {
    uint id;
    uint productId;
    address seller;
    uint256 proposedUnitPrice;
    uint quantity;
    uint timestamp;
  }

  // Estrutura responsável por armazenar dados das propostas
  // em cima das ofertas anunciadas na plataforma. Cada proposta
  // possui um valor unitário proposto em cima da quantidade
  // de unidades a serem compradas.
  struct OfferBid {
    uint id;
    uint offerId;
    address bider;
    uint256 proposedUnitPrice;
    uint quantity;
    uint timestamp;
  }

  // Estrutura responsável por armazenar dados dos pedidos
  // realizados quando uma oferta é aceita pelo vendedor.
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

  struct Delivery {
    uint id;
    uint orderCourierBidId;
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
  uint public lastDeliveryId = 0;

  Product[] public products;
  Offer[] public offers;
  OfferBid[] public offersBid;
  Order[] public orders;
  OrderCourierBid[] public orderCourierBids;
  Delivery[] public deliveries;

  event ProductRegistered(uint id);
  event OfferRegistered(uint id);
  event OfferBidRegistered(uint id, uint256 totalValue);
  event OrderRegistered(uint id, uint256 totalValue);
  event OrderCourierBidRegistered(uint id, address courier, uint256 price);
  event DeliveryRegistered(uint id, uint orderCourierBidId, address courier, uint256 price);

  event OfferBidRefused(uint id);

  event OrderCourierBidRefused(uint id);

  event OrderCourierBidAcceptedBySeller(uint id);
  event OrderCourierBidAcceptedByBuyer(uint id);

  event DeliveryConfirmedByCourier(uint id);
  event DeliveryConfirmedByBuyer(uint id);

  event OrderFinished(uint id);

  mapping (uint => bool) public isOfferStanding;

  mapping (uint => uint) public offerAvailableQuantity;

  mapping (uint => bool) public isOfferBidAccepted;
  mapping (uint => bool) public isOfferBidRefused;

  mapping (address => uint256) public tokensAtStake;

  mapping (uint => bool) public orderHasCourier;

  mapping (uint => bool) public orderHasFinished;

  mapping (uint => bool) public orderCourierBidAcceptedBySeller;
  mapping (uint => bool) public orderCourierBidAcceptedByBuyer;

  mapping (uint => bool) public orderCourierBidRefused;

  mapping (uint => bool) public isDeliveryPending;

  mapping (uint => bool) public deliveryConfirmedByCourier;
  mapping (uint => bool) public deliveryConfirmedByBuyer;

  mapping (uint => bool) public isDeliveryCancelled;

  function Marketplace() onlyOwner public {
    //
  }

  function registerProductFrom(address _owner, string name, uint256 unitPrice) onlyOwner public returns (uint) {
    require(!isAccountFrozen[_owner]);
    require(unitPrice > 0);

    Product storage product = products[products.length++];

    product.id = lastProductId++;
    product.owner = _owner;
    product.name = name;
    product.unitPrice = unitPrice;
    product.timestamp = block.timestamp;

    ProductRegistered(product.id);

    return product.id;
  }

  function registerOfferFrom(address seller, uint productId, uint256 proposedUnitPrice, uint quantity) onlyOwner public returns (uint) {
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

    OfferRegistered(offer.id);

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
    transferFrom(bider, owner, totalValue);

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

    OfferBidRegistered(offerBid.id, totalValue);

    return offerBid.id;
  }

  function refuseOfferBid(uint offerBidId) onlyOwner public returns (bool) {
    require(offerBidId <= offersBid.length);

    require(!isOfferBidRefused[offerBidId]);
    require(!isOfferBidAccepted[offerBidId]);

    OfferBid memory offerBid = offersBid[offerBidId];

    uint256 totalValue = offerBid.proposedUnitPrice * offerBid.quantity;

    transferFrom(owner, offerBid.bider, totalValue);

    tokensAtStake[offerBid.bider] -= totalValue;

    isOfferBidRefused[offerBidId] = true;

    offerAvailableQuantity[offerBid.offerId] += offerBid.quantity;

    OfferBidRefused(offerBidId);

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

    OrderRegistered(order.id, totalValue);

    orderHasCourier[order.id] = false;

    orderHasFinished[order.id] = false;

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

    transferFrom(courier, owner, price);

    tokensAtStake[courier] += price;

    OrderCourierBidRegistered(orderCourierBid.id, courier, price);

    orderCourierBidAcceptedBySeller[orderCourierBid.id] = false;
    orderCourierBidAcceptedByBuyer[orderCourierBid.id] = false;

    orderCourierBidRefused[orderCourierBid.id] = false;

    return orderCourierBid.id;
  }

  function refuseOrderCourierBid(uint orderCourierBidId) onlyOwner public returns (bool) {
    require(orderCourierBidId <= orderCourierBids.length);

    require(!orderCourierBidAcceptedBySeller[orderCourierBidId]);
    require(!orderCourierBidAcceptedByBuyer[orderCourierBidId]);

    OrderCourierBid memory orderCourierBid = orderCourierBids[orderCourierBidId]; 

    orderCourierBidRefused[orderCourierBid.id] = true;

    transferFrom(owner, orderCourierBid.courier, orderCourierBid.price);

    tokensAtStake[orderCourierBid.courier] += orderCourierBid.price;

    OrderCourierBidRefused(orderCourierBid.id);

    return true;
  }

  function acceptOrderCourierBidBySeller(uint orderCourierBidId, address seller) onlyOwner public returns (bool) {
    require(orderCourierBidId <= orderCourierBids.length);

    require(!orderCourierBidAcceptedBySeller[orderCourierBidId]);

    OrderCourierBid memory orderCourierBid = orderCourierBids[orderCourierBidId]; 
    
    Order memory order = orders[orderCourierBid.orderId];

    require(order.seller == seller);

    orderCourierBidAcceptedBySeller[orderCourierBidId] = true;

    OrderCourierBidAcceptedBySeller(orderCourierBidId);

    return true;
  }

  function acceptOrderCourierBidByBuyer(uint orderCourierBidId, address buyer) onlyOwner public returns (bool) {
    require(orderCourierBidId <= orderCourierBids.length);

    require(!orderCourierBidAcceptedByBuyer[orderCourierBidId]);

    OrderCourierBid memory orderCourierBid = orderCourierBids[orderCourierBidId]; 
    
    Order memory order = orders[orderCourierBid.orderId];

    require(order.buyer == buyer);

    orderCourierBidAcceptedByBuyer[orderCourierBidId] = true;

    OrderCourierBidAcceptedByBuyer(orderCourierBidId);

    return true;
  }

  function acceptOrderCourierBidByCourier(uint orderCourierBidId, address courier) onlyOwner public returns (uint) {
    require(orderCourierBidId <= orderCourierBids.length);

    require(orderCourierBidAcceptedBySeller[orderCourierBidId]);
    require(orderCourierBidAcceptedByBuyer[orderCourierBidId]);

    OrderCourierBid memory orderCourierBid = orderCourierBids[orderCourierBidId]; 

    require(orderCourierBid.courier == courier);

    Order memory order = orders[orderCourierBid.orderId];
    
    orderHasCourier[order.id] = true;

    Delivery storage delivery = deliveries[deliveries.length];

    delivery.id = lastDeliveryId++;
    delivery.orderCourierBidId = orderCourierBidId;
    delivery.orderId = order.id;
    delivery.courier = courier;
    delivery.price = orderCourierBid.price;
    delivery.timestamp = block.timestamp;

    DeliveryRegistered(delivery.id, orderCourierBidId, courier, delivery.price);

    isDeliveryPending[delivery.id] = true;

    return delivery.id;
  }

  function confirmDeliveryByCourier(uint deliveryId, address courier) onlyOwner public returns (bool) {
    require(deliveryId <= deliveries.length);

    require(isDeliveryPending[deliveryId]);
    require(!isDeliveryCancelled[deliveryId]);

    require(!deliveryConfirmedByCourier[deliveryId]);

    Delivery memory delivery = deliveries[deliveryId];

    require(delivery.courier == courier);

    deliveryConfirmedByCourier[delivery.id] = true;

    DeliveryConfirmedByCourier(delivery.id);

    return true;
  }

  function confirmDeliveryByBuyer(uint deliveryId, address buyer) onlyOwner public returns (bool) {
    require(deliveryId <= deliveries.length);

    require(isDeliveryPending[deliveryId]);
    require(!isDeliveryCancelled[deliveryId]);

    require(deliveryConfirmedByCourier[deliveryId]);

    require(!deliveryConfirmedByBuyer[deliveryId]);

    Delivery memory delivery = deliveries[deliveryId];

    Order memory order = orders[delivery.orderId];

    require(order.buyer == buyer);

    deliveryConfirmedByBuyer[deliveryId] = true;
    isDeliveryPending[deliveryId] = false;

    uint256 deliveryReward = delivery.price * 2;

    transferFrom(owner, delivery.courier, deliveryReward);

    tokensAtStake[delivery.courier] -= delivery.price;

    uint256 orderTotalValue = order.agreedUnitPrice * order.quantity;

    transferFrom(order.buyer, order.seller, orderTotalValue);

    tokensAtStake[order.buyer] -= orderTotalValue;

    DeliveryConfirmedByBuyer(delivery.id);

    orderHasFinished[order.id] = true;

    OrderFinished(order.id);

    return true;
  }

  function cancelDeliveryByCourier(uint id, address courier) onlyOwner public returns (bool) {
    // TODO

    return true;
  }

}
