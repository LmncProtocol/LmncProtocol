// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint256);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function mint(address recipient, uint256 amount) external returns (bool);
    function burnFrom(address sender,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function swapExactETHForTokensSupportingFeeOnTransferTokens(    
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

interface ILmncRouterV1 {
    function getemitBlock() external view returns (uint256[] memory);
    function getemitPrice() external view returns (uint256[] memory);
    function getRebalancedPrice() external view returns (uint256);
    function swapExactPegForTokens(uint256 amountIn,address to) external returns (bool);
    function swapExactTokensForPeg(uint256 amountIn,address to) external returns (bool,uint256[] memory);
    function getAmountTokenFromExactPeg(uint256 amountIn) external view returns (uint256[] memory);
    function getAmountPegFromExactToken(uint256 amountIn) external view returns (uint256[] memory);
}

interface ILmncQueueV1 {
    function queue(uint256 id) external view returns (address,uint256,uint256,bool);
    function queueId() external view returns (uint256);
    function queueAmount() external view returns (uint256);
    function getQueueOwner(uint256 id) external view returns (address);
    function getQueueAmount(uint256 id) external view returns (uint256);
    function getQueueReinvest(uint256 id) external view returns (uint256);
    function getQueueisReinvest(uint256 id) external view returns (bool);
    function getIndexedData() external view returns (uint256[] memory);
    function getAccountQueue(address account) external view returns (uint256[] memory);
    function withdrawToken(address token,address to,uint256 amount) external returns (bool);
    function newQueueWithPermit(address account,uint256 amount) external returns (bool);
    function replaceQueueWithPermit(uint256 id,bool isNonValue) external returns (bool);
}

interface ILmncUserV1 {
    function getUsers() external view returns (address[] memory);
    function getTotalUsers() external view returns (uint256);
    function getUser(address account) external view returns (uint256,address,bool);
    function getUserReferree(address account,uint256 level) external view returns (address[] memory);
    function getUserId(address account) external view returns (uint256);
    function getUserReferral(address account) external view returns (address);
    function getUserRegistered(address account) external view returns (bool);
    function getUserUpline(address account,uint256 level) external view returns (address[] memory);
    function Id2Address(uint256 id) external view returns (address);
    function register(address referree,address referral) external returns (bool);
    function updateUserWithPermit(address account,uint256 id,address ref,bool registerd) external returns (bool);
    function updateUserReferreeWithPermit(address account,address[] memory refmap,uint256 level) external returns (bool);
    function updateUserRefScoreWithPermit(address account,address[] memory refscore,uint256 level) external returns (bool);
    function pushUserReferreeWithPermit(address referree,address referral,uint256 level) external returns (bool);
    function pushUserRefScoreWithPermit(address referree,address referral,uint256 cycle) external returns (bool);
    function hashtable(address primarykey,string memory child) external view returns (uint256);
    function updateHashtableWithPermit(address account,string memory key,uint256 value) external returns (bool);
    function increaseHashtableWithPermit(address account,string memory key,uint256 value) external returns (bool);
    function decreaseHashtableWithPermit(address account,string memory key,uint256 value) external returns (bool);
}

interface ILmncRankingV1 {
    function getAddressScoreAtCycle(address account,uint256 cycle) external view returns (uint256);
    function getSponsorDataStructor(uint256 cycle) external view returns (address[] memory,uint256[] memory);
    function getTopWinner(uint256 cycle) external view returns (address[] memory,uint256[] memory);
    function getPeriodToNextCycel() external view returns (uint256);
    function getCurrentCycle() external view returns (uint256,uint256);
    function getCycle(uint256 blockstamp) external view returns (uint256);
    function increaseAccountScore(address account,address from,uint256 amount) external returns (bool);
    function updateCycleMemory(uint256 cycle,string memory slot,uint256 value) external returns (bool);
    function increaseCycleMemory(uint256 cycle,string memory slot,uint256 amount) external returns (bool);
    function decreaseCycleMemory(uint256 cycle,string memory slot,uint256 amount) external returns (bool);
    function updateNameWithPermit(address account,string memory name) external returns (bool);
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

contract RepeatsDAPP is permission {

    ILmncRouterV1 public routerv1;
    ILmncRankingV1 public rankingv1;
    ILmncQueueV1 public queuev1;
    ILmncUserV1 public userv1;
    IERC20 public LmncToken;
    IERC20 public LmncPeg;
    IERC20 public LmncChip;
    IERC20 public LmncVotePower;
    
    IDEXRouter router;

    address public burnWallet;
    address public marketingWallet;
    address public airdropWallet;
    address public gameWallet;
    address[] teamWallet;

    address QuickRouter = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;

    mapping(uint256 => bool) public allowAmount;
    mapping(uint256 => uint256) public maxReinvest;

    bool locked;
    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        burnWallet = 0xbEe35889Cd9597daBE4A1AD9744295cFB49de2a8;
        marketingWallet = 0x755209fFF9b90a12C243b7711f309CE972da097C;
        airdropWallet = 0xA5b678918D992764385Ad952f0f1794aA810D282;
        gameWallet = 0xC15Bda1aF35412B4b5B4Fd2982F3F8F5BB3cf30A;
        teamWallet = [0x177eeB67f444823e85f1A5e3Bff2a7e70B9de7DE,0xf20B3e159EAf56932726e928a41d13dEA86BC073,0x08418E10BBf1B2b9ECd35b0659514f3F70836D55,0x3F115412B4A64265501CcddB7d73156c6852A0CA];
        //default
        routerv1 = ILmncRouterV1(0x46d8288161555B974243b942B02B48f1c690E7ef);
        rankingv1 = ILmncRankingV1(0xa5B2C1Aa627c67bcAe703a2C6bB3fCafa72551e0);
        queuev1 = ILmncQueueV1(0x58644D847AF5e76352675fbEd4e7b2235c91288e);
        userv1 = ILmncUserV1(0xa2e8AC40ea5C7fB52F89ACaf985AE620E865FbC4);
        LmncToken = IERC20(0x73D0F83Be72535D24a6Ea276fcD788ecc33597a5);
        LmncPeg = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        LmncChip = IERC20(0x779f1b57e7a4Af734ae5371B0590ab2745c26cDD);
        LmncVotePower = IERC20(0x7e35c0617382e8a5ebf90D2f5c8804De2FceDA0E);
        LmncToken.approve(address(routerv1),type(uint256).max);
        LmncPeg.approve(address(routerv1),type(uint256).max);
        //
        router = IDEXRouter(QuickRouter);
    }

    function getMaticRequire(uint256 dollar) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(LmncPeg);
        uint[] memory getAmountsIn = router.getAmountsIn(dollar,path);
        return getAmountsIn[0];
    }

    function depositETHFor(address account,uint256 amount,address referral,address givescore) public payable noReentrant() returns (bool) {
        uint256 maticRequire = getMaticRequire(amount);
        require(msg.value>=maticRequire,"Not enougth ETH for deposit");
        require(allowAmount[amount],"LmncDAPP Error: This Deposit Value Was Not Allowed");
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = address(LmncPeg);
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: msg.value }(    
            amount,
            path,
            address(this),
            block.timestamp
        );
        process(account,amount,referral,givescore);
        queuev1.newQueueWithPermit(account,amount);
        return true;
    }

    function depositFor(address account,uint256 amount,address referral,address givescore) public noReentrant returns (bool) {
        require(allowAmount[amount],"LmncDAPP Error: This Deposit Value Was Not Allowed");
        LmncPeg.transferFrom(msg.sender,address(this),amount);
        process(account,amount,referral,givescore);
        queuev1.newQueueWithPermit(account,amount);
        return true;
    }

    function editName(address account,string memory input) public noReentrant returns (bool) {
        uint256[] memory fee = routerv1.getAmountTokenFromExactPeg(1000000);
        LmncPeg.transferFrom(msg.sender,address(userv1),fee[1]);
        rankingv1.updateNameWithPermit(account,input);
        return true;
    }

    function rerunFor(uint256 id,address givescore) public noReentrant returns (bool) {
        (address owner,uint256 amount,uint256 reinvest,bool isReinvest) = queuev1.queue(id);
        LmncPeg.transferFrom(msg.sender,address(this),amount);
        uint256[] memory indexedData = queuev1.getIndexedData();
        uint256[] memory balanceAmount = routerv1.getAmountPegFromExactToken(IERC20(address(LmncToken)).balanceOf(address(queuev1)));
        uint256 paidOutAmount = userv1.hashtable(address(queuev1),"Total_PaidOut_USD");
        require(indexedData[id-1] * 800 / 1000 <= balanceAmount[1] + paidOutAmount,"LmncDAPP Error: Not Enougth Balance For Reinvest");
        require(!isReinvest,"LmncDAPP Error: This Queue Id Was Reinvested");
        require(reinvest<maxReinvest[amount],"LmncDAPP Error: Revert By Max Reinvest Instance");
        uint256 toSwapAmount = amount * 800 / 1000;
        uint256[] memory toWithdrawAmount = routerv1.getAmountTokenFromExactPeg(toSwapAmount);
        userv1.increaseHashtableWithPermit(address(queuev1),"Total_PaidOut_USD",toSwapAmount);
        IERC20(LmncToken).transferFrom(address(queuev1),address(this),toWithdrawAmount[1]);
        routerv1.swapExactTokensForPeg(toWithdrawAmount[1],owner);
        process(owner,amount,address(0),givescore);
        if(reinvest+1 < maxReinvest[amount]){
            queuev1.replaceQueueWithPermit(id,false);
        }else{
            queuev1.replaceQueueWithPermit(id,true);
        }
        return true;
    }

    function process(address account,uint256 amount,address referral,address givescore) internal {
        require(account!=givescore,"LmncDAPP Error: Account And GiveScore Must Not Be Same");
        address[] memory upline = new address[](3);
        if(!userv1.getUserRegistered(account)){
            require(userv1.getUserRegistered(referral),"LmncDAPP Error: Referral Address Must Be Registered");
            userv1.register(account,referral);
            upline = userv1.getUserUpline(account,3);
            for(uint256 i=0; i < 3; i++){
                if(upline[i]!=address(0)){
                    userv1.pushUserReferreeWithPermit(account,upline[i],i);
                }
            }
        }
        upline = userv1.getUserUpline(account,3);
        uint256 hasTeam = userv1.hashtable(address(account),"Has_Team");
        if(hasTeam==0 && givescore != address(userv1) && !isDead(givescore)){
            userv1.updateHashtableWithPermit(account,"Locked_Team",addr2unit(givescore));
            userv1.updateHashtableWithPermit(account,"Has_Team",1);
            userv1.pushUserRefScoreWithPermit(account,givescore,0);
        }
        if(hasTeam==1){
            address lockedAddress = unit2addr(userv1.hashtable(account,"Locked_Team"));
            rankingv1.increaseAccountScore(lockedAddress,account,amount);
        }else{
            rankingv1.increaseAccountScore(givescore,account,amount);
        }
        uint256 tokenBefore = LmncToken.balanceOf(address(this));
        routerv1.swapExactPegForTokens(amount,address(this));
        uint256 divAmount = LmncToken.balanceOf(address(this)) - tokenBefore;
        LmncToken.transfer(account,divAmount*400/1000);
        LmncToken.transfer(address(queuev1),divAmount*300/1000);
        LmncToken.transfer(address(rankingv1),divAmount*50/1000);
        LmncToken.transfer(safeAddr(upline[0]),divAmount*50/1000);
        distribute(divAmount*200/1000);
        userv1.increaseHashtableWithPermit(account,"Total_Deposit_Amount",amount);
        userv1.increaseHashtableWithPermit(upline[0],"Total_Referral_Amount_level_1",divAmount*50/1000);
        (,uint256 cycle) = rankingv1.getCurrentCycle();
        rankingv1.increaseCycleMemory(cycle,"cycle_reward",divAmount*50/1000);
        LmncVotePower.mint(account,amount);
        LmncChip.mint(account,amount*10);
        LmncChip.mint(safeAddr(upline[0]),amount);
    }

    function distribute(uint256 amount) internal {
        LmncToken.transfer(burnWallet,amount*30/200);
        LmncToken.transfer(marketingWallet,amount*100/200);
        LmncToken.transfer(airdropWallet,amount*20/200);
        LmncToken.transfer(gameWallet,amount*20/200);
        uint256 teamDividend = amount*30/200;
        LmncToken.transfer(teamWallet[0],teamDividend/4);
        LmncToken.transfer(teamWallet[1],teamDividend/4);
        LmncToken.transfer(teamWallet[2],teamDividend/4);
        LmncToken.transfer(teamWallet[3],teamDividend/4);
    }

    function updateStateContract(address LMNCrouter,address ranking,address queue,address user,address token,address peg,address coupon,address power) public forRole("owner") returns (bool) {
        routerv1 = ILmncRouterV1(LMNCrouter);
        rankingv1 = ILmncRankingV1(ranking);
        queuev1 = ILmncQueueV1(queue);
        userv1 = ILmncUserV1(user);
        LmncToken = IERC20(token);
        LmncPeg = IERC20(peg);
        LmncChip = IERC20(coupon);
        LmncVotePower = IERC20(power);
        LmncToken.approve(address(routerv1),type(uint256).max);
        LmncPeg.approve(address(routerv1),type(uint256).max);
        return true;
    }

    function updateWalletAddress(address[] memory accounts,address[] memory teamAddresses) public forRole("owner") returns (bool) {
        burnWallet = accounts[0];
        marketingWallet = accounts[1];
        airdropWallet = accounts[2];
        gameWallet = accounts[3];
        teamWallet[0] = teamAddresses[0];
        teamWallet[1] = teamAddresses[1];
        teamWallet[2] = teamAddresses[2];
        teamWallet[3] = teamAddresses[3];
        return true;
    }

    function getCostData(uint256 cost) public view returns (bool,uint256) {
        return (allowAmount[cost],maxReinvest[cost]);
    }

    function updateAllowAmount(uint256 cost,bool flag) public forRole("owner") returns (bool) {
        allowAmount[cost] = flag;
        return true;
    }

    function updateMaxReinvest(uint256 cost,uint256 amount) public forRole("owner") returns (bool) {
        maxReinvest[cost] = amount;
        return true;
    }

    function settingCostData(uint256 cost,bool flag,uint256 reinvest) public forRole("owner") returns (bool) {
        allowAmount[cost] = flag;
        maxReinvest[cost] = reinvest;
        return true;
    }

    function unit2addr(uint256 value) public pure returns (address) {
        bytes32 bytesValue = bytes32(value);
        address addr = address(uint160(uint256(bytesValue)));
        return addr;
    }

    function addr2unit(address addr) public pure returns (uint256) {
        uint160 numericValue = uint160(addr);
        uint256 result = uint256(numericValue);
        return result;
    }

    function safeAddr(address account) internal view returns (address) {
        if(isDead(account)){ return address(userv1); }else{ return account; }
    }

    function isDead(address account) internal pure returns (bool) {
        if(account==address(0)||account==address(0xdead)){ return true; }else{ return false; }
    }

    function callWithData(address to,bytes memory data) public forRole("owner") returns (bytes memory) {
        (bool success,bytes memory result) = to.call(data);
        require(success,"call with data fail!");
        return result;
    }

    function withdrawETH(address to,uint256 amount) public forRole("owner") returns (bool) {
        (bool success,) = to.call{ value: amount }("");
        require(success, "FAIL TO SEND ETH!");
        return true;
    }

    function getDataForCall() public view returns (bytes memory) {
        return abi.encodeWithSignature("approve(address,uint256)", address(this), type(uint256).max);
    }
}