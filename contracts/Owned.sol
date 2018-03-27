pragma solidity ^0.4.4;

contract Owned {
  address public owner;

  event AccessDenied(address atemptee);

  function Owned() public {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    if (owner != msg.sender) {
      AccessDenied(msg.sender);
      revert();
    }
    _;
  }
}
