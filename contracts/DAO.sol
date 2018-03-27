pragma solidity ^0.4.4;

import "./TokenIssuer.sol";

contract DAO is TokenIssuer {
  
  

  function DAO() onlyOwner public {
  }

}
