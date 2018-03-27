pragma solidity ^0.4.4;

import "./Owned.sol";

contract TokenIssuer is Owned {
  string public name = "Marketplace Token";
  string public symbol = "MKTT";

  uint8 public decimals = 18;

  uint256 public totalSupply = (10**6) * 10 ** uint256(decimals);

  mapping (address => uint256) public balanceOf;

  mapping (address => bool) public isAccountFrozen;

  event Transfer(address from, address to, uint256 value);
  event Burnt(address from, uint256 value);

  event AccountFrozen(address account);
  event AccountUnfrozen(address account);

  function TokenIssuer() onlyOwner public {
    balanceOf[owner] = totalSupply;
  }

  function _transfer(address from, address to, uint256 value) private returns (bool) {
    require(to != 0x0);

    require(!isAccountFrozen[from]);
    require(!isAccountFrozen[to]);

    require(balanceOf[from] >= value);
    require(balanceOf[to] + value > balanceOf[to]);

    uint256 previousBalance = balanceOf[from] + balanceOf[to];

    balanceOf[from] -= value;
    balanceOf[to] += value;

    Transfer(from, to, value);

    assert(balanceOf[from] + balanceOf[to] == previousBalance + value);

    return true;
  }

  function transfer(address to, uint256 value) public returns (bool) {
    return _transfer(msg.sender, to, value);
  }

  function transferFrom(address from, address to, uint256 value) onlyOwner public returns (bool) {
    return _transfer(from, to, value);
  }

  function burnFrom(address from, uint256 value) onlyOwner public returns (bool) {
    require(balanceOf[from] >= value);
    
    balanceOf[from] -= value;
    totalSupply -= value;
    
    Burnt(from, value);

    return true;
  }

  function freezeAccount(address account) onlyOwner public returns (bool) {
    isAccountFrozen[account] = true;

    AccountFrozen(account);

    return true;
  }

  function unfreezeAccount(address account) onlyOwner public returns (bool) {
    isAccountFrozen[account] = false;

    AccountUnfrozen(account);

    return true;
  }
}
