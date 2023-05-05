// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract StakingRewards {

    IERC20 public immutable stakingToken; //質押的token
    IERC20 public immutable rewardsToken; //獎勵的token

    address public owner;

    // 支付獎勵的持續時間（以秒為單位）
    uint public duration;
    // 獎勵結束時間戳
    uint public finishAt;
    // 最後更新時間和獎勵完成時間的最小值
    uint public updatedAt;
    // 每秒支付的獎勵
    uint public rewardRate;
    // （獎勵率 * dt * 1e18 / 總供應量）的總和
    uint public rewardPerTokenStored;
    // 用戶地址 => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // 用戶地址 => 待領取獎勵
    mapping(address => uint) public rewards;

    // 總質押
    uint public totalSupply;
    // 用戶地址 => 質押金額
    mapping(address => uint) public balanceOf;

    constructor(address _stakingToken, address _rewardToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "not authorized");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }

        _;
    }

    function lastTimeRewardApplicable() public view returns (uint) {
        return _min(finishAt, block.timestamp);
    }

    function rewardPerToken() public view returns (uint) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }

    //質押
    function stake(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    //領回
    function withdraw(uint _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    //計算質押獎勵
    function earned(address _account) public view returns (uint) {
        return
            ((balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    //領取質押獎勵
    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    //設定獎勵結束時間戳
    function setRewardsDuration(uint _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    //通知獎勵金額
    function notifyRewardAmount(
        uint _amount
    ) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= finishAt) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (finishAt - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "reward amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    //取最小數
    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}