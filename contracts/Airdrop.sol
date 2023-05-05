// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//空投合約
contract Airdropper {
    using SafeERC20 for IERC20;

    address private owner; // 擁有者
    uint256 public airdropPerAmount = 1; // 每人每次可以領取的空投數量,未設置則每人每次只能領一次
    uint256 public airdropTotalAmount = 1; // 每人可以領取的空投總數,未設置則每人可領取最大數為1
    uint256 public airdropTerm; // 多久可以領取一次（單位s）,未設置則每人只能領一次
    uint256 public airdropStartTime; // 空投開始時間（時間戳）,未設置不限制
    uint256 public airdropDeadline; // 空投截止時間（時間戳）,未設置不限制
    address public tokenAddress; // 空投token地址

    mapping(address => uint256) public airdropRecord; // 每個人空投領取總額
    mapping(address => uint256) public airdropTimeRecord; // 最後一次領取空投時間

    constructor() {
        owner = msg.sender;
    }

    // 批量發放空投，dests和values兩個數組長度若相等，則給不同地址發放對應數量token，如果values只有一個元素，則每個地址發放等量token
    function doAirdrop(address[] memory dests, uint256[] memory values)
        external
        virtual
        returns (uint256)
    {
        // 批量發放一般為官方操作，不受時間、領取額度等以上各種條件限制
        require(msg.sender == owner, "Airdropper: forbidden");
        require(tokenAddress != address(0), "Airdropper: address not zero");
        uint256 i = 0;
        while (i < dests.length) {
            uint256 sendAmount = values.length == 1 ? values[0] : values[i];
            // 判斷當前合約中剩餘token是否夠發放數量，如果不夠則結束發放並返回已發放的最後一個索引
            if (ERC20(tokenAddress).balanceOf(address(this)) < sendAmount) {
                break;
            }
            // 接收地址不為0，發放數量不為0，則執行發放
            if (dests[i] != address(0) && sendAmount > 0) {
                IERC20(tokenAddress).safeTransfer(dests[i], sendAmount);
            }

            i++;
        }
        return i;
    }

    // 個人領取空投
    function getAirdrop() external virtual returns (bool) {
        // token地址不能為0地址
        require(tokenAddress != address(0), "Airdropper: address not zero");
        // 每人每次可以領取的空投數量要大於0
        require(airdropPerAmount > 0, "Airdropper: no parameter set");
        // 當前時間要大於空投開始時間
        require(block.timestamp >= airdropStartTime, "Airdropper: not started");
        if (airdropTotalAmount > 0) {
            // 如果設置了 每人可以領取的空投總數 這個參數，則驗證已領取數量要小於這個總數
            require(
                airdropRecord[msg.sender] < airdropTotalAmount,
                "Airdropper: total amount limit"
            );
        }
        if (airdropTerm > 0) {
            // 如果設置了領取周期參數，則驗證當前時間減去上次領取時間大於這個週期
            require(
                block.timestamp - airdropTimeRecord[msg.sender] > airdropTerm,
                "Airdropper: term limit"
            );
        } else {
            // 如果沒有設置週期參數，則驗證沒有領取過可以領取，只能領1次
            require(
                airdropRecord[msg.sender] == 0,
                "Airdropper: you have already received"
            );
        }
        if (airdropDeadline > 0) {
            // 如果設置了空投截止時間，則驗證當前時間小於截止時間
            require(airdropDeadline > block.timestamp, "Airdropper: deadline");
        }
        // 驗證當前合約token數量夠發放數量
        require(
            ERC20(tokenAddress).balanceOf(address(this)) >= airdropPerAmount,
            "Airdropper: insufficient assets"
        );
        // 執行發放
        IERC20(tokenAddress).safeTransfer(msg.sender, airdropPerAmount);
        // 累計領取總數
        airdropRecord[msg.sender] += airdropPerAmount;
        // 記錄最後領取時間
        airdropTimeRecord[msg.sender] = block.timestamp;

        return true;
    }

    // 充入token
    function recharge(address _tokenAddress, uint256 _amount)
        external
        virtual
        returns (bool)
    {
        require(msg.sender == owner, "Airdropper: forbidden");
        require(_tokenAddress != address(0), "Airdropper: forbidden");

        // 驗證充入的token和配置的地址一致
        require(
            _tokenAddress == tokenAddress,
            "Airdropper: Error token address"
        );

        // 執行充入token
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        return true;
    }

    // 提出剩餘token
    function withdraw() external virtual returns (bool) {
        require(msg.sender == owner, "Airdropper: forbidden");
        require(tokenAddress != address(0), "Airdropper: address not zero");
        // 將剩餘token全部轉給合約發布者
        IERC20(tokenAddress).safeTransfer(
            owner,
            ERC20(tokenAddress).balanceOf(address(this))
        );
        tokenAddress = address(0); // 重置token地址

        return true;
    }

    /**
     * 以下是配置各個參數的接口，只有合約發布者可以調用
     */
    function setPerAmount(uint256 _airdropPerAmount)
        external
        virtual
        returns (bool)
    {
        require(msg.sender == owner, "Airdropper: forbidden");
        airdropPerAmount = _airdropPerAmount;

        return true;
    }

    // 設定空投總數
    function setTotalAmount(uint256 _airdropTotalAmount)
        external
        virtual
        returns (bool)
    {
        require(msg.sender == owner, "Airdropper: forbidden");
        airdropTotalAmount = _airdropTotalAmount;

        return true;
    }

    // 設定多久可以領取一次（單位s）,未設置則每人只能領一次
    function setTerm(uint256 _airdropTerm) external virtual returns (bool) {
        require(msg.sender == owner, "Airdropper: forbidden");
        airdropTerm = _airdropTerm;

        return true;
    }

    // 設定空投開始時間
    function setStartTime(uint256 _airdropStartTime)
        external
        virtual
        returns (bool)
    {
        require(msg.sender == owner, "Airdropper: forbidden");
        airdropStartTime = _airdropStartTime;

        return true;
    }

    // 設定空投結束時間
    function setDeadline(uint256 _airdropDeadline)
        external
        virtual
        returns (bool)
    {
        require(msg.sender == owner, "Airdropper: forbidden");
        airdropDeadline = _airdropDeadline;

        return true;
    }

    // 設定空投Token Address
    function setTokenAddress(address _tokenAddress)
        external
        virtual
        returns (bool)
    {
        require(msg.sender == owner, "Airdropper: forbidden");
        tokenAddress = _tokenAddress;

        return true;
    }
}
