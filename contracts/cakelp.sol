  // SPDX-License-Identifier: MIT
  //CAKE LP address: 0xce53728d94255409Dfe6DD78247A678270d3D08b
  //BSC Testnet: 0xAE4C99935B1AA0e76900e86cD155BFA63aB77A2a 
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LPVault is Ownable{
    using SafeMath for uint;
    bytes4 private constant SELECTOR = bytes4(
        keccak256(bytes("transfer(address,uint256)"))
    );

    IERC20 private lptoken; 
    mapping(address => uint) public savings;
    mapping(address => uint) public moments;
    address[] public savers;
    uint lockTime;

    struct LP{
        address saver;
        uint amount;
        uint time;
    } 
    constructor(){
        lptoken= IERC20(0xAE4C99935B1AA0e76900e86cD155BFA63aB77A2a);
        lockTime= 100* 1 seconds;
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        //调用token合约地址的低级transfer方法
        //solium-disable-next-line
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        //确认返回值为true并且返回的data长度为0或者解码后为true
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Vault: TRANSFER_FAILED"
        );
    }
    
    function setLockTime(uint _lockTime) public onlyOwner{
        lockTime= _lockTime;
    }
    function stake() public{
        stake(lptoken.balanceOf(address(msg.sender)));
    }
    function stake(uint amnt) public {
        address saver= address(msg.sender);

        require(amnt>0, "0 fund to stake");
        require(lptoken.balanceOf(saver)>= amnt, "Not enough LP tokens");
        if(moments[saver]==0){
            // First time saver in
            savers.push(saver);
            savings[saver]=0;
        }

        lptoken.transferFrom(saver, address(this), amnt);
        moments[saver]= block.timestamp;
        savings[saver]=  savings[saver].add(amnt);
    }

    function withdraw() public {
        return withdraw(savings[address(msg.sender)]);
    }

    function withdraw(uint256 amnt) public {
        address saver= address(msg.sender);

        require(savings[saver]>= amnt, "Not enough LP tokens");
        require(block.timestamp>= moments[saver]+ lockTime, "Still in lock");

        //lptoken.transferFrom(address(this), saver, amnt);
        //(bool success, ) = address(lptoken).call(abi.encodeWithSignature("tranfer(address,uint)", saver, amnt));
        //require(success, "withdraw from vault failed.");
        _safeTransfer(address(lptoken), saver, amnt);
        savings[saver]= savings[saver].sub(amnt);
    }

    function stakeBalance() view public returns (uint){
        return stakeBalance(address(this));
    }
    function stakeBalance(address who) view public returns (uint){
        return savings[who];
    }

    function getLPs() view public returns(LP [] memory){
        uint count= savers.length;
        uint LPcount=0;

        for (uint i = 0; i < count; i++) {
            if (savings[savers[i]]> 0) {LPcount++;}
        }

        LP[] memory items=new LP[](LPcount);
        for (uint i = 0; i < count; i++) {
            if (savings[savers[i]]> 0) {
                LPcount--;
                items[LPcount]= LP(savers[i], savings[savers[i]], moments[savers[i]]);
            }
        }
        return items;
    }
}