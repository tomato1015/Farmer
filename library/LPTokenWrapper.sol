pragma solidity ^0.5.0;


import "./SafeMath.sol";
import "./ERC20Detailed.sol";
import "./SafeERC20.sol";

import "./Initializable.sol";

contract LPTokenWrapper is Initializable {
    using SafeMath for uint256; 
    using SafeERC20 for ERC20Detailed;  

    ERC20Detailed internal  y; 

    uint256 private _totalSupply;                  
    mapping(address => uint256) private _balances;     

 
    function initialize(address _y) internal  initializer {
        y = ERC20Detailed(_y);    
    }

   
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

  
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

   
    function stake(uint256 amount) public  {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount); 
        y.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        y.transfer(msg.sender, amount);
    }


    function exitSub(uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
    }
}
