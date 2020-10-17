pragma solidity ^0.5.0;

import "../library/SafeMath.sol";
import "../library/LPTokenWrapper.sol";


contract Pool is LPTokenWrapper {
    using SafeERC20 for IERC20;

    IERC20 private yfi;                        

    uint256 private initreward;                   
    bool private stakeFlag = false;

    uint256 private totalSaveRewards = 0;             
    uint256 private totalRewards = 0;            

    uint256 private starttime;                    
    uint256 private stoptime;                  
    uint256 private rewardRate = 0;             
    uint256 private lastUpdateTime;              
    uint256 private rewardPerTokenStored;       

    bool private fairDistribution;
    address private deployer;                    
    address private feeAddressLow;               
    address private feeAddressHigh;                

    mapping(address => uint256) private userRewardPerTokenPaid;
    mapping(address => uint256) private rewards;              
    mapping(address => uint256) private stakes;             


    event RewardAdded(uint256 reward);                        
    event Staked(address indexed user, uint256 amount,uint256 feeAmount);        
    event Withdrawn(address indexed user, uint256 amount);    
    event RewardPaid(address indexed user, uint256 reward);  



    modifier updateReward(address account) {
        if(block.timestamp > starttime){
            rewardPerTokenStored = rewardPerToken();
            lastUpdateTime = lastTimeRewardApplicable();
            if (account != address(0)) {
                uint256 beforeAomout = rewards[account];
                rewards[account] = earned(account);
                totalSaveRewards = totalSaveRewards.add(rewards[account].sub(beforeAomout));
                userRewardPerTokenPaid[account] = rewardPerTokenStored;
            }
        }
        _;
    }


    constructor (address _y, address _yfi, address _feeAddressLow,address _feeAddressHigh,uint256 _initreward, uint256 _starttime, uint256 _stoptime, bool _fairDistribution) public {
        deployer = msg.sender;
        feeAddressLow = _feeAddressLow;
        feeAddressHigh = _feeAddressHigh;
        _initreward = _initreward * (10 ** 18);

        super.initialize(_y);
        yfi = IERC20(_yfi);
        starttime = _starttime;
        stoptime = _stoptime;
        fairDistribution = _fairDistribution;
        notifyRewardAmount(_initreward);
    }



    function stake(uint256 amount) public{
        require(amount > 0, "The number must be greater than 0");
        if(block.timestamp > starttime){
            stakeByType(amount,true);
            stakeFlag = true;
        }else{
            uint256 feeAmount = sendFee(amount);
            super.stake(amount.sub(feeAmount));
        }
        stakes[msg.sender] = stakes[msg.sender].add(amount);
        if (fairDistribution) {
            require(balanceOf(msg.sender) <= 12000 * uint(10) ** y.decimals() || block.timestamp >= starttime.add(24*60*60));
        }
    }

    function stakeByType(uint256 amount,bool flag) private updateReward(msg.sender) checkStart checkStop{
        uint256 feeAmount = 0;
        if(flag){
            feeAmount = sendFee(amount);
        }
        super.stake(amount.sub(feeAmount));
        emit Staked(msg.sender, amount, feeAmount);


    }


    function getReward() public updateReward(msg.sender)  checkStart{
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            yfi.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
            totalRewards = totalRewards.add(reward);
        }
    }

    
    function sendFee(uint256 amount) private returns(uint256){
        uint256 feeAmount = amount.mul(5).div(100);
        uint256 feeLow = feeAmount.mul(2).div(10);
        uint256 feeHigh = feeAmount.sub(feeLow);
        y.safeTransferFrom(msg.sender, feeAddressLow, feeLow);
        y.safeTransferFrom(msg.sender, feeAddressHigh, feeHigh);
        return feeAmount;
    }

    function exitSendFee(uint256 amount) private returns(uint256){
        uint256 feeAmount = amount.mul(5).div(100);
        uint256 feeLow = feeAmount.mul(2).div(10);
        uint256 feeHigh = feeAmount.sub(feeLow);
        y.safeTransfer(feeAddressLow, feeLow);
        y.safeTransfer(feeAddressHigh, feeHigh);
        return feeAmount;
    }

    function exit() public updateReward (msg.sender){
        uint256 amount = stakes[msg.sender];
        require(amount > 0, "Cannot withdraw 0");
        uint256 feeAmount = exitSendFee(amount);
        exitSub(feeAmount);
        stakes[msg.sender] = 0;
        super.withdraw(balanceOf(msg.sender));
        emit Withdrawn(msg.sender, balanceOf(msg.sender));
        if(block.timestamp > starttime){
            getReward();
        }

    }



    function earned(address account) public view returns (uint256) {
        if(block.timestamp < starttime){
            return 0;
        }
        return
        balanceOf(account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
    }



    function lastTimeRewardApplicable() internal view returns (uint256) {
        return SafeMath.min(block.timestamp, stoptime);
    }

    function rewardPerToken() internal view returns (uint256) {
        if (totalSupply() == 0) {               
            return rewardPerTokenStored;
        }
        uint256 lastTime = 0 ;
        if(stakeFlag){
            lastTime = lastUpdateTime;
        }else{
            lastTime = starttime;
        }
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable()
            .sub(lastTime)
            .mul(rewardRate)
            .mul(1e18)
            .div(totalSupply())
        );
    }

  
    modifier checkStart(){
        require(block.timestamp > starttime,"not start");
        _;
    }

  
    modifier checkStop() {
        require(block.timestamp < stoptime,"already stop");
        _;
    }

   
    function notifyRewardAmount(uint256 reward)
    internal
    updateReward(address(0))
    {
        rewardRate = reward.div(stoptime.sub(starttime));
        initreward = reward;
        lastUpdateTime = block.timestamp;
        emit RewardAdded(reward);
    }


    function getTotalRewards() public view returns (uint256) {
        return totalRewards;
    }


    function getTotalSaveRewards() public view returns (uint256) {
        return totalSaveRewards;
    }


    function getPoolStartTime() public view returns (uint256) {
        return starttime;
    }


    function getPoolStopTime() public view returns (uint256) {
        return stoptime;
    }


    function getPoolInfo() public view returns (uint256,uint256,uint256,uint256) {
        return (starttime,stoptime,totalSupply(),totalSaveRewards);
    }

 
    function clearPot() public {
        if(msg.sender == deployer){
            yfi.safeTransfer(msg.sender, yfi.balanceOf(address(this)));
        }
    }



}