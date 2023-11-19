// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
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

contract VoterRouter is permission {

    address public tokenAddress;

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
    mapping(address => mapping(uint256 => mapping(bytes => bool))) public voted;

    constructor(address token) {
        tokenAddress = token;
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