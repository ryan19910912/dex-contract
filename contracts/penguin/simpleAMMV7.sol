// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
//goerli 0xae6B0f75b55fa4c90b2768e3157b7000241A41c5 merge 0x4a9C121080f6D9250Fc0143f41B595fD172E31bf
// V1 0xf60440f93a677AB6968E1Fd10cf8a6cE61941131
// V2 0x8b175c421E9307F0365dd37bc32Dda5df95C4946
// V3 0x3ea585565c490232b0379C7D3C3A9fC3fA5C9c0C
// V4  0x6D81EE8B003422Ee9d1255aceA42386eCBD20a60 merge 0x540d7E428D5207B30EE03F2551Cbb5751D3c7569
// V6 merge 0xaE036c65C649172b43ef7156b009c6221B596B8b
// V7 sepolia 0x69911ED54C0393Afd31B278B93D908Fb4387A94f
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract AMM {
    address public immutable developer;

    ERC20 public immutable token;
    address public constant ETH_ADDRESS = address(0);

    uint256 public reserveETH; // eth
    uint256 public reserveERC; // erc20

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    uint256 public immutable fee;

    constructor(address _token, uint256 _fee) {
        require(_fee>0 &&_fee <= 100, "fee > 10%");
        developer = msg.sender;
        token = ERC20(_token);
        fee = _fee;
        //check ERC20 interface
        token.name();
        token.symbol();
        token.decimals();
    }

    function _mint(address _to, uint256 _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    function _burn(address _from, uint256 _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    function _update(uint256 _reserve0, uint256 _reserve1) private {
        reserveETH = _reserve0;
        reserveERC = _reserve1;
    }

    function swap(uint256 _amountIn) public payable returns (uint256 amountOut) {
        require(msg.value == _amountIn, "ETH amount mismatch");

        amountOut = getInETHPredictOutputERC(_amountIn);
        require(amountOut > 0, "Insufficient output amount");
        uint256 feeToDeveloper = _amountIn * fee*totalSupply/(reserveETH*2000);

        _mint(developer,feeToDeveloper); // 50% of the profit to developer

        token.transfer(msg.sender, amountOut);

        _update(address(this).balance, token.balanceOf(address(this)));
    }
    function swapTokenForETH(uint256 _amountIn) public returns (uint256 amountOut) {
        require(_amountIn > 0, "Insufficient output amount");

        amountOut = getInERCPredictOutputETH(_amountIn);
        require(amountOut > 0, "Insufficient output amount");
        uint256 feeToDeveloper = _amountIn * fee*totalSupply/(reserveERC*2000);
        _mint(developer,feeToDeveloper); // 50% of the profit to developer

        token.transferFrom(msg.sender, address(this), _amountIn);
        payable(msg.sender).transfer(amountOut);

        _update(address(this).balance, token.balanceOf(address(this)));
    }
    function swap_WithSlipLock(uint256 _amountIn,uint256 _forwardOutput,uint256 _slipLock) public payable returns (uint256 amountOut)
    {
        require(msg.value == _amountIn, "ETH amount mismatch");

        amountOut = getInETHPredictOutputERC(_amountIn);
        require(amountOut > 0, "Insufficient output amount");
        require(amountOut >= (_forwardOutput*(1000-_slipLock)/1000), "SlipLock");
        uint256 feeToDeveloper = _amountIn *fee*totalSupply/(reserveETH*2000);
        _mint(developer,feeToDeveloper); // 50% of the profit to developer

        token.transfer(msg.sender, amountOut);

        _update(address(this).balance, token.balanceOf(address(this)));
    }
    function swapTokenForETH_WithSlipLock(uint256 _amountIn,uint256 _forwardOutput,uint256 _slipLock) public returns (uint256 amountOut) {
        require(_amountIn > 0, "Insufficient output amount");

        amountOut = getInERCPredictOutputETH(_amountIn);
        require(amountOut > 0, "Insufficient output amount");
        require(amountOut >= (_forwardOutput*(1000-_slipLock)/1000), "SlipLock");

        uint256 feeToDeveloper = _amountIn *fee*totalSupply/(reserveERC*2000);
        _mint(developer,feeToDeveloper); // 50% of the profit to developer

        token.transferFrom(msg.sender, address(this), _amountIn);
        payable(msg.sender).transfer(amountOut);

        _update(address(this).balance, token.balanceOf(address(this)));
    }
    function addLiquidity(uint256 _amountERC) external payable returns (uint256 shares) {
        token.transferFrom(msg.sender, address(this), _amountERC);

        uint256 _amountETH = msg.value;

        if (reserveETH > 0 || reserveERC > 0) {
            require(reserveETH * _amountERC*(1000-fee) <= reserveERC * _amountETH*1000&&reserveETH * _amountERC*1000 >= reserveERC * _amountETH*(1000-fee), "x / y != dx / dy +- fee%");
        }

        if (totalSupply == 0) {
            shares = _sqrt(_amountETH * _amountERC);
        } else {
            shares = Math.min(
                (_amountETH * totalSupply) / reserveETH,
                (_amountERC * totalSupply) / reserveERC
            );
        }
        require(shares > 0, "shares = 0");
        _mint(msg.sender, shares);

        _update(address(this).balance, token.balanceOf(address(this)));
    }

    function removeAllLiquidity() external returns (uint256 amountETH, uint256 amountERC) {
        return _removeLiquidity(msg.sender,balanceOf[msg.sender]);
    }
    function removeLiquidity(uint256 _shares) external returns (uint256 amountETH, uint256 amountERC) {
        require(_shares <= balanceOf[msg.sender], "Insufficient balance");
        return _removeLiquidity(msg.sender, _shares);
    }
    function _removeLiquidity(address _user, uint256 _shares) internal returns (uint256 amountETH, uint256 amountERC) {
        amountETH = (_shares * reserveETH) / totalSupply;
        amountERC = (_shares * reserveERC) / totalSupply;
        require(amountETH > 0 && amountERC > 0, "amountETH or amountERC = 0");

        _burn(_user, _shares);

        payable(_user).transfer(amountETH);
        token.transfer(_user, amountERC);

        _update(address(this).balance, token.balanceOf(address(this)));

    }
    function my_shars() public view returns(uint256){
        return balanceOf[msg.sender];
    }
    function sharesOf(address _user) public view returns(uint256){
        return balanceOf[_user];
    }

    function _sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    function getETHPrice() public view returns (uint256) {
        require(reserveETH > 0 && reserveERC > 0, "Invalid ETH reserves");
        return (reserveERC * 10**18) / reserveETH;
    }
    function getERCPrice() public view returns (uint256) {
        require(reserveETH > 0 && reserveERC > 0, "Invalid ERC20 reserves");
        uint256 decimals = ERC20(address(token)).decimals();
        return (reserveETH * 10**decimals) / reserveERC;
    }

    function getInETHPredictOutputERC(uint256 _amount) public view returns (uint256) {
        require(reserveETH > 0 && reserveERC > 0 && _amount>0, "Invalid ERC20 reserves");
        uint256 amountInWithFee=(_amount * (1000-fee)) / 1000;
        return (reserveERC * amountInWithFee) / (reserveETH + amountInWithFee);
    }
    function getInERCPredictOutputETH(uint256 _amount) public view returns (uint256) {
        require(reserveETH > 0 && reserveERC > 0 && _amount>0, "Invalid ETH reserves");
        uint256 amountInWithFee=(_amount * (1000-fee)) / 1000;
        return (reserveETH * amountInWithFee) / (reserveERC + amountInWithFee);
    }
    function getInERCOutputETHLiquidityAmount(uint256 _amount) public view returns (uint256) {
        require(reserveETH > 0 && reserveERC > 0,"Invalid reserves");
        require(_amount>0, string(abi.encodePacked("Invalid", token.symbol(),"reserves")));
          
        return reserveETH * _amount / reserveERC;
    }
    function getInETHOutputERCLiquidityAmount(uint256 _amount) public view returns (uint256) {
        require(reserveETH > 0 && reserveERC > 0,"Invalid reserves");
        require(_amount>0, "Invalid ETH amount");
        return reserveERC * _amount / reserveETH;
    }
    

}