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

interface ILmncRakingV1 {
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

contract LeaderAward is permission {
    
    uint256 public genesisBlock;
    address public tokenAddress;
    
    struct SponsorData {
        address[] scoreOwner;
        uint256[] scoreAmount;
    }

    struct WinnerData {
        mapping(uint256 => address) winnerAddress;
        mapping(uint256 => uint256) winnerScore;
    }

    uint256 maxEnumWinner = 5;
    uint256 periodPerCycle = 2592000;
    uint256[] public rewardDividend = [50,30,10,5,5];

    mapping(uint256 => SponsorData) dataSponsor;
    mapping(uint256 => WinnerData) dataWinner;
    mapping(address => mapping(uint256 => uint256)) public whereAddress;
    mapping(address => mapping(uint256 => bool)) registered;

    mapping(uint256 => mapping(string => uint256)) public cycleMemory;
    mapping(address => mapping(uint256 => bool)) public claimed;
    mapping(address => uint256) public claimedAmount;

    mapping(address => string) public teamName;
    mapping(address => mapping(uint256 => address[])) scoreGivenMap;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public scoreGiven;

    constructor() {
        genesisBlock = block.timestamp;
    }

    function forceClaim(uint256 cycle) public returns (bool) {
        (address[] memory winners,) = getTopWinner(cycle);
        (,uint256 currentCycle) = getCurrentCycle();
        if(currentCycle>cycle){
            for(uint256 i=0; i<winners.length; i++){
                uint256 reward = getAmountToClaim(winners[i],cycle);
                if(reward>0){
                    claimTopReward(winners[i],cycle);
                }
            }
        }
        return true;
    }

    function claimTopReward(address account,uint256 cycle) public returns (bool) {
        uint256 reward = getAmountToClaim(account,cycle);
        require(reward>0,"This Account Claimed Or Need Requirement");
        claimed[account][cycle]==true;
        IERC20(tokenAddress).transfer(account,reward);
        claimedAmount[account] += reward;
        return true;
    }

    function getAmountToClaim(address account,uint256 cycle) public view returns (uint256) {
        (,uint256 currentCycle) = getCurrentCycle();
        if(claimed[account][cycle]==false && cycle < currentCycle && getAddressScoreAtCycle(account,cycle) > 0 && account!=address(0) && account!=address(0xdead)){
            uint256 amongReward = cycleMemory[cycle]["cycle_reward"];
            return amongReward * rewardDividend[whereAddress[account][cycle]] / 100;
        }
        return 0;
    }

    function getScoreGivenMap(address account,uint256 cycle) public view returns (address[] memory) {
        return scoreGivenMap[account][cycle];
    }

    function getAddressScoreAtCycle(address account,uint256 cycle) public view returns (uint256) {
        uint256 whereAmI = whereAddress[account][cycle];
        if(whereAmI==0 && dataSponsor[cycle].scoreOwner[0] != account){
            return 0;
        }
        return dataSponsor[cycle].scoreAmount[whereAmI];
    }

    function getSponsorDataStructor(uint256 cycle) public view returns (address[] memory,uint256[] memory) {
        return (dataSponsor[cycle].scoreOwner,dataSponsor[cycle].scoreAmount);
    }

    function getTopWinner(uint256 cycle) public view returns (address[] memory,uint256[] memory) {
        address[] memory winnerAddress = new address[](maxEnumWinner);
        uint256[] memory winnerScore = new uint256[](maxEnumWinner);
        for(uint256 i=0; i<maxEnumWinner; i++){
            winnerAddress[i] = dataWinner[cycle].winnerAddress[i];
            winnerScore[i] = dataWinner[cycle].winnerScore[i];
        }
        return (winnerAddress,winnerScore);
    }

    function getPeriodToNextCycel() public view returns (uint256) {
        uint256 nextCycle = getCycle(block.timestamp) + 1; //BUG
        uint256 endedTime = (nextCycle * periodPerCycle) + genesisBlock;
        return endedTime - block.timestamp;
    }

    function getCurrentCycle() public view returns (uint256,uint256) {
        return (block.timestamp,getCycle(block.timestamp));
    }

    function getCycle(uint256 blockstamp) public view returns (uint256) {
        if(blockstamp>genesisBlock){
            uint256 period = blockstamp - genesisBlock;
            return period / periodPerCycle;
        }else{
            revert("Undefine Cycle");
        }
    }

    function updateTokenAddress(address token) public forRole("permit") returns (bool) {
        tokenAddress = token;
        return true;
    }

    function updateNameWithPermit(address account,string memory name) public forRole("permit") returns (bool) {
        teamName[account] = name;
        return true;
    }

    function increaseAccountScore(address account,address from,uint256 amount) public forRole("permit") returns (bool) {
        (,uint256 cycle) = getCurrentCycle();
        if(cycle>0){ forceClaim(cycle-1); }
        increaseAccountScoreExactCycle(account,from,cycle,amount);
        return true;
    }

    function updateCycleMemory(uint256 cycle,string memory slot,uint256 value) public forRole("permit") returns (bool) {
        cycleMemory[cycle][slot] = value;
        return true;
    }

    function increaseCycleMemory(uint256 cycle,string memory slot,uint256 amount) public forRole("permit") returns (bool) {
        cycleMemory[cycle][slot] += amount;
        return true;
    }

    function decreaseCycleMemory(uint256 cycle,string memory slot,uint256 amount) public forRole("permit") returns (bool) {
        cycleMemory[cycle][slot] -= amount;
        return true;
    }

    function increaseAccountScoreExactCycle(address account,address from,uint256 cycle,uint256 amount) internal {
        registerAccount(account,cycle);
        dataSponsor[cycle].scoreAmount[whereAddress[account][cycle]] += amount;
        if(scoreGiven[from][account][cycle]==0){
            scoreGivenMap[account][cycle].push(from);
        }
        scoreGiven[from][account][cycle] += amount;
        adsignData(account,cycle);
    }

    function registerAccount(address account,uint256 cycle) internal {
        if(!registered[account][cycle]){
            registered[account][cycle] = true;
            dataSponsor[cycle].scoreOwner.push(account);
            dataSponsor[cycle].scoreAmount.push(0);
            whereAddress[account][cycle] = dataSponsor[cycle].scoreOwner.length-1;
        }
    }

    function adsignData(address account,uint256 cycle) internal {
        uint256 score;
        uint256 where = whereAddress[account][cycle];
        (bool dipucate,uint256 index) = isAddressWinner(account,cycle);
        if(dipucate){
            dataWinner[cycle].winnerAddress[index] = account;
            dataWinner[cycle].winnerScore[index] = dataSponsor[cycle].scoreAmount[where];
        }else{
            for (uint256 i = 0; i < maxEnumWinner; i++) {
                score = dataSponsor[cycle].scoreAmount[where];
                if(score>dataWinner[cycle].winnerScore[i]){
                    if(dipucate){
                        
                    }else{
                        dataWinner[cycle].winnerAddress[0] = account;
                        dataWinner[cycle].winnerScore[0] = score;
                    }
                    break;
                }
            }
        }
        sortWinnerData(cycle);
    }

    function isAddressWinner(address account,uint256 cycle) internal view returns (bool,uint256) {
        for (uint256 i = 0; i < maxEnumWinner; i++) {
            if(account==dataWinner[cycle].winnerAddress[i]){ return (true,i); }
        }
        return (false,0);
    }

    function sortWinnerData(uint256 cycle) internal {
        for (uint256 i = 1; i < maxEnumWinner; i++) {
            address addr = dataWinner[cycle].winnerAddress[i];
            uint256 key = dataWinner[cycle].winnerScore[i];
            int j = int(i) - 1;
            while ((int(j) >= 0) && (dataWinner[cycle].winnerScore[uint256(j)] > key)) {
                dataWinner[cycle].winnerAddress[uint256(j+1)] = dataWinner[cycle].winnerAddress[uint256(j)];
                dataWinner[cycle].winnerScore[uint256(j+1)] = dataWinner[cycle].winnerScore[uint256(j)];
                j--;
            }
            dataWinner[cycle].winnerAddress[uint256(j+1)] = addr;
            dataWinner[cycle].winnerScore[uint256(j+1)] = key;
        }
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
    
}