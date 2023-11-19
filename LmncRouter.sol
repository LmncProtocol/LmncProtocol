// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    function updateRouter(address newRouter) external returns (bool);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address recipient, uint256 amount) external returns (bool);
    function burnFrom(address sender,uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
}

interface ILmncRouterV1 {
    function getemitBlock() external view returns (uint256[] memory);
    function getemitPrice() external view returns (uint256[] memory);
    function getRebalancedPrice() external view returns (uint256);
    function swapExactPegForTokens(uint256 amountIn,address to) external returns (bool,uint256[] memory);
    function swapExactTokensForPeg(uint256 amountIn,address to) external returns (bool,uint256[] memory);
    function getAmountTokenFromExactPeg(uint256 amountIn) external view returns (uint256[] memory);
    function getAmountPegFromExactToken(uint256 amountIn) external view returns (uint256[] memory);
}

contract permission {

    address private _owner;
    mapping(address => mapping(string => bytes32)) private _permit;

    modifier forRole(string memory str) {
        require(checkpermit(msg.sender,str),"Permit Revert!");
        _;
    }

    constructor() {
        newpermit(msg.sender,"owner");
        newpermit(msg.sender,"permit");
        _owner = msg.sender;
    }

    function owner() public view returns (address) { return _owner; }
    function newpermit(address adr,string memory str) internal { _permit[adr][str] = bytes32(keccak256(abi.encode(adr,str))); }
    function clearpermit(address adr,string memory str) internal { _permit[adr][str] = bytes32(keccak256(abi.encode("null"))); }
    function checkpermit(address adr,string memory str) public view returns (bool) {
        if(_permit[adr][str]==bytes32(keccak256(abi.encode(adr,str)))){ return true; }else{ return false; }
    }

    function grantRole(address adr,string memory role) public forRole("owner") returns (bool) { newpermit(adr,role); return true; }
    function revokeRole(address adr,string memory role) public forRole("owner") returns (bool) { clearpermit(adr,role); return true; }

    function transferOwnership(address adr) public forRole("owner") returns (bool) {
        newpermit(adr,"owner");
        clearpermit(msg.sender,"owner");
        _owner = adr;
        return true;
    }

    function renounceOwnership() public forRole("owner") returns (bool) {
        newpermit(address(0),"owner");
        clearpermit(msg.sender,"owner");
        _owner = address(0);
        return true;
    }
}

contract LMNCProtocolRouter is permission {

    event Swap(address indexed msgSender,address indexed to,uint256 amountIn,uint256[] data);
    event Rebalance(uint256 changedPrice,uint256 formPrice,uint256 toPrice,uint256 index);

    uint256[] emitBlock;
    uint256[] emitPrice;

    uint256 public price;
    uint256 public gap;
    uint256 public rebalanceAt;
    uint256 public denominator;
    uint256 public split;

    uint256 public buy_price;
    uint256 public stack_gap;

    address public tokenAddress;
    address public pegAddress;

    uint256 public voteStartTimer;
    uint256 public voteEndingTimer;
    uint256 public voteTotalAccept;
    uint256 public voteTotalDecide;

    bool public proporsalCalled = true;
    address public proporsalContract;
    bytes public proporsalData;
    address[] voter;
    uint256[] votePower;
    bool[] votestate;

    address[] users;

    struct User {
        uint256 totalBuy;
        uint256 totalSell;
    }

    mapping(address => User) public user;
    mapping(address => mapping(uint256 => mapping(bytes => bool))) public voted;

    bool locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address token,address peg) {
        tokenAddress = token;
        pegAddress = peg;
        price = 1e4;
        gap = 50 * 1e6;
        split = 3000 * 1e6;
        rebalanceAt = 30;
        denominator = 1000;
        buy_price = price;
    }

    function getemitBlock() public view returns (uint256[] memory) { return emitBlock; }
    function getemitPrice() public view returns (uint256[] memory) { return emitPrice; }

    function getUsers() public view returns (address[] memory) {
        return users;
    }

    function simpleSwap(uint256 amountIn,address to) public forRole("permit") noReentrant returns (bool,uint256[] memory) {
        (bool success,uint256[] memory result) = _swapExactPegForTokens(amountIn,to);
        require(success,"swapExactPegForTokens Fail!");
        return (success,result);
    }

    function swapExactPegForTokens(uint256 amountIn,address to) public forRole("permit") noReentrant returns (bool) {
        do{
            if(amountIn>split){
                amountIn -= split;
                (bool success,) = _swapExactPegForTokens(split,to);
                require(success,"swapExactPegForTokens Fail!");
            }else{
                (bool success,) = _swapExactPegForTokens(amountIn,to);
                require(success,"swapExactPegForTokens Fail!");
                break;
            }   
        }while(true);
        return (true);
    }

    function _swapExactPegForTokens(uint256 amountIn,address to) internal returns (bool,uint256[] memory) {
        require(!isVoting(),"Voting Live!");
        uint256[] memory result = getAmountTokenFromExactPeg(amountIn);
        uint256 amountOut = result[1];
        IERC20(pegAddress).transferFrom(msg.sender,address(this),amountIn);
        IERC20(tokenAddress).mint(to,amountOut);
        buy_price = result[3];
        stack_gap = result[4];
        rebalanced();
        user[msg.sender].totalBuy += amountIn;
        emit Swap(msg.sender,to,amountIn,result);
        return (true,result);
    }

    function swapExactTokensForPeg(uint256 amountIn,address to) public noReentrant returns (bool,uint256[] memory) {
        require(!isVoting(),"Voting Live!");
        uint256[] memory result = getAmountPegFromExactToken(amountIn);
        uint256 amountOut = result[1];
        IERC20(tokenAddress).burnFrom(msg.sender,amountIn);
        IERC20(pegAddress).transfer(to,amountOut);
        rebalanced();
        user[msg.sender].totalSell += amountOut;
        emit Swap(msg.sender,to,amountIn,result);
        return (true,result);
    }

    function rebalanced() internal {
        rebalancePrice();
        emitBlock.push(block.timestamp);
        emitPrice.push(buy_price);
    }

    function getAmountTokenFromExactPeg(uint256 amountIn) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](5);
        uint256 current_price = buy_price;
        uint256 amount = amountIn;
        uint256 amountOut;
        uint256 stacking = stack_gap;
        uint256 token_decimals = IERC20(tokenAddress).decimals();
        if(stacking>=gap){
            current_price = increasePriceTokenomics(current_price);
            stacking -= gap;
        }
        while(amount>0){
            if(amount>=gap){
                amountOut += gap / current_price * (10**token_decimals);
                amount -= gap;
                current_price = increasePriceTokenomics(current_price);
            }else{
                amountOut += amount / current_price * (10**token_decimals);
                stacking += amount;
                amount = 0;
            }
        }
        result[0] = amountIn;
        result[1] = amountOut;
        result[2] = buy_price;
        result[3] = current_price;
        result[4] = stacking;
        return result;
    }

    function getAmountPegFromExactToken(uint256 amountIn) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](4);
        uint256 pegPerToken = getRebalancedPrice();
        uint8 token_decimals = IERC20(tokenAddress).decimals();
        uint256 amountOut = amountIn * pegPerToken / (10**token_decimals);
        result[0] = amountIn;
        result[1] = amountOut;
        result[2] = buy_price;
        result[3] = pegPerToken;
        return result;
    }

    function getRebalancedPrice() public view returns (uint256) {
        uint256 pegBalance = IERC20(pegAddress).balanceOf(address(this));
        uint256 totalSupply = IERC20(tokenAddress).totalSupply();
        return getSimmulateBalanced(pegBalance,totalSupply);
    }

    function getSimmulateBalanced(uint256 pegBalance,uint256 totalSupply) internal view returns (uint256) {
        uint8 token_decimals = IERC20(tokenAddress).decimals();
        if(totalSupply>0){ return (pegBalance * (10**token_decimals)) / totalSupply; }
        return 0;
    }

    function sync() external returns (bool) {
        require(msg.sender==tokenAddress,"LmncRouter: Only LmncToken Can Call!");
        rebalancePrice();
        return true;
    }

    function rebalancePrice() internal {
        uint256 rebalancing = getRebalancedPrice();
        if(rebalancing>0){
            if(rebalancing>buy_price){
                uint256 changedPrice = rebalancing - buy_price;
                buy_price = rebalancing;
                emit Rebalance(changedPrice,buy_price,rebalancing,0);
            }
            if(buy_price>rebalancing){
                uint256 changedPrice = buy_price - rebalancing;
                uint256 changedMax = rebalancing * rebalanceAt / denominator;
                if(changedPrice > changedMax){
                    buy_price = rebalancing + changedMax;
                    emit Rebalance(changedPrice,buy_price,rebalancing,1);
                }
            }
        }
    }

    function increasePriceTokenomics(uint256 currentPrice) internal pure returns (uint256) {
        currentPrice = currentPrice * 1001;
        currentPrice = currentPrice / 1000;
        return currentPrice;
    }

    function getVoter() public view returns (address[] memory,uint256[] memory,bool[] memory) {
        return (voter,votePower,votestate);
    }

    function voteRequest(address to,bytes memory data) public forRole("owner") returns (bool) {
        require(!isVoting(),"Voting Live!");
        voteStartTimer = block.timestamp;
        voteEndingTimer = voteStartTimer + 60 * 7; //7 min
        proporsalContract = to;
        proporsalData = data;
        proporsalCalled = false;
        voter = [address(0)];
        votePower = [0];
        votestate = [false];
        voteTotalAccept = 0;
        voteTotalDecide = 0;
        return true;
    }

    function vote(uint256 timestamp,bytes memory data,bool accept) public returns (bool) {
        require(!voted[msg.sender][timestamp][data],"This Address Applied This Proporsal");
        voted[msg.sender][timestamp][data] = true;
        uint256 power = IERC20(tokenAddress).balanceOf(msg.sender);
        voter.push(msg.sender);
        votePower.push(power);
        votestate.push(accept);
        if(accept){
            voteTotalAccept += power;
        }else{
            voteTotalDecide += power;
        }
        return true;
    }

    function proporsalCall() public forRole("owner") returns (bool) {
        require(proporsalCalled==false,"Need Excreate Voter");
        uint256 requireSupply = IERC20(tokenAddress).totalSupply() * 50 / 100;
        bool bypass = voteTotalAccept>requireSupply;
        bool noReject = voteTotalDecide<requireSupply && block.timestamp > voteEndingTimer;
        if(bypass||noReject){
            if(keccak256(proporsalData) == keccak256(abi.encodeWithSignature("migrate()"))){
                IERC20(tokenAddress).updateRouter(proporsalContract);
                IERC20(tokenAddress).approve(proporsalContract,type(uint256).max);
                IERC20(pegAddress).approve(proporsalContract,type(uint256).max);
            }
            (bool success,) = proporsalContract.call(proporsalData);
            require(success,"call fail!");
            proporsalCalled = true;
        }else{
            if(block.timestamp < voteEndingTimer){
                revert("Can't call proporsal now");
            }else{
                proporsalCalled = true;
            }
        }
        return true;
    }

    function isVoting() public view returns (bool) {
        if(proporsalCalled == false){ return true; }else{ return false; }
    }

    function withdrawETH(address to,uint256 amount) public forRole("owner") returns (bool) {
        (bool success,) = to.call{ value: amount }("");
        require(success, "FAIL TO SEND ETH!");
        return true;
    }

    receive() external payable {}

}