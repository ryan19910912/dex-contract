// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract AMM {
    IERC20 public immutable token0; //流動池token0
    IERC20 public immutable token1; //流動池token1

    uint256 public reserve0; //token0數量
    uint256 public reserve1; //token1數量

    uint256 public totalSupply; //目前總數
    mapping(address => uint256) public balanceOf; //用戶的流動性token map

    event removeLiquidityEvent(uint256 amount0, uint256 amount1);

    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    //用戶提供token0、token1時，增加該用戶流動性token及增加總數
    function _mint(address _to, uint256 _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    //用戶撤回token0、token1時，減少該用戶流動性token
    function _burn(address _from, uint256 _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    //更新token0、token1數量
    function _update(uint256 _reserve0, uint256 _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    //幣幣交換
    function swap(address _tokenIn, uint256 _amountIn)
        external
        returns (uint256 amountOut)
    {
        //判斷是否為token0 or token1
        require(
            _tokenIn == address(token0) || _tokenIn == address(token1),
            "invalid token"
        );
        require(_amountIn > 0, "amount in = 0");

        // 判斷 token0, token1 順序
        bool isToken0 = _tokenIn == address(token0);
        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint256 reserveIn,
            uint256 reserveOut
        ) = isToken0
                ? (token0, token1, reserve0, reserve1)
                : (token1, token0, reserve1, reserve0);

        // 把tokenIn轉給給合約
        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        //計算 0.3% 手續費
        uint256 amountInWithFee = (_amountIn * 997) / 1000;

        // 透過 x * y = k 計算該換多少
        amountOut =
            (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);

        // 把tokenOut轉給該用戶
        tokenOut.transfer(msg.sender, amountOut);

        // 更新token0、token1數量
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    //空投幣交換 1空投幣可換2個代幣
    function airdropswap(address _tokenIn, uint256 _amountIn)
        external
        returns (uint256 amountOut)
    {
        //判斷是否為token0
        require(
            _tokenIn == address(token0),
            "invalid token"
        );
        require(_amountIn > 0, "amount in = 0");

        // 把tokenIn轉給給合約
        token0.transferFrom(msg.sender, address(this), _amountIn);

        amountOut = _amountIn * 2;

        // 把token1轉給該用戶
        token1.transfer(msg.sender, amountOut);

        // 更新token0、token1數量
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    function swapCalculate(address _tokenIn, uint256 _amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        //判斷是否為token0 or token1
        require(
            _tokenIn == address(token0) || _tokenIn == address(token1),
            "invalid token"
        );
        require(_amountIn > 0, "amount in = 0");
        
        // 判斷 token0, token1 順序
        bool isToken0 = _tokenIn == address(token0);

        (uint256 reserveIn, uint256 reserveOut) = isToken0
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        
        //計算 0.3% 手續費
        uint256 amountInWithFee = (_amountIn * 997) / 1000;
        amountOut =
            (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);
    }

    //添加進資金池
    function addLiquidity(uint256 _amount0, uint256 _amount1)
        external
        returns (uint256 shares)
    {
        // 需添加等值流動性
        // if (reserve0 > 0 || reserve1 > 0) {
        //     require(
        //         reserve0 * _amount1 == reserve1 * _amount0,
        //         "x / y != dx / dy"
        //     );
        // }

        // 第一次添加
        if (totalSupply == 0) {
            // 流動性 token 數量計算 = √ (amount0 * amount1)
            shares = _sqrt(_amount0 * _amount1);
        } else {
            // 計算流動性 token 比例，精度問題取小的
            shares = _min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            );
        }
        require(shares > 0, "shares = 0");

        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        _mint(msg.sender, shares);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    //從資金池撤回
    function removeLiquidity(uint256 _shares)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        // 計算該取回的 token0 及 token1 數量
        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "amount0 or amount1 = 0");

        _burn(msg.sender, _shares);
        _update(bal0 - amount0, bal1 - amount1);

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        emit removeLiquidityEvent(amount0, amount1); //通知前端
    }

    //開根號
    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    //取最小值
    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
}
