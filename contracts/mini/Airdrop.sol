/*空投合約
@notice 向多個地址轉帳ERC20代幣 使用前須先授權
@param _token 轉帳的ERC20代幣地址
@param _addresses 接收空投用戶的地址數組
@param _amounts 對應每個接收空投用戶要接收的代幣數量數組
*/
contract Airdrop {
    function multiTransferToken(address _token,address[] calldata _addresses,uint256[] calldata _amounts) external payable {
    // 檢查：_addresses和_amounts數組的長度是否相等(1對1關係)
    require(_addresses.length == _amounts.length, "Lengths of Addresses and Amounts NOT EQUAL");
    IERC20 token = IERC20(_token); // 宣告IERC合約變量
    uint _amountSum = getSum(_amounts); // 統計空投代幣總數量
    // 檢查：授權代幣數量 >= 空投代幣總數量
    require(token.allowance(msg.sender, address(this)) >= _amountSum, "Need Approve ERC20 token");
    
    // for循環 利用transferFrom函數發送空投
    for (uint8 i; i < _addresses.length; i++) {
        token.transferFrom(msg.sender, _addresses[i], _amounts[i]);
    }
}

    function getSum(uint256[] calldata _arr) public pure returns(uint sum)
    {
        for(uint i = 0; i < _arr.length; i++)
            sum = sum + _arr[i];
    }

}