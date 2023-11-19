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
    function updateUserRefScoreWithPermit(address account,address[] memory refscore,uint256 cycle) external returns (bool);
    function pushUserReferreeWithPermit(address referree,address referral,uint256 level) external returns (bool);
    function pushUserRefScoreWithPermit(address referree,address referral,uint256 cycle) external returns (bool);
    function hashtable(address primarykey,string memory child) external view returns (uint256);
    function updateHashtableWithPermit(address account,string memory key,uint256 value) external returns (bool);
    function increaseHashtableWithPermit(address account,string memory key,uint256 value) external returns (bool);
    function decreaseHashtableWithPermit(address account,string memory key,uint256 value) external returns (bool);
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

contract Lodge is permission {

    address[] users;

    struct User {
        uint256 id;
        address ref;
        bool registerd;
        mapping(uint256 => address[]) refmap;
        mapping(uint256 => address[]) refscore;
    }

    mapping(address => User) user;
    mapping(uint256 => address) public Id2Address;
    mapping(address => mapping(string => uint256)) public hashtable;
    
    constructor() {
        users.push(address(this));
        user[address(this)].id = users.length-1;
        user[address(this)].ref = address(0);
        user[address(this)].registerd = true;
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }

    function getTotalUsers() public view returns (uint256) {
        return users.length;
    }

    function getUser(address account) public view returns (uint256,address,bool) {
        return (user[account].id,user[account].ref,user[account].registerd);
    }

    function getUserReferree(address account,uint256 level) public view returns (address[] memory) {
        return user[account].refmap[level];
    }

    function getUserRefScore(address account,uint256 cycle) public view returns (address[] memory) {
        return user[account].refscore[cycle];
    }

    function getUserId(address account) public view returns (uint256) {
        return user[account].id;
    }

    function getUserReferral(address account) public view returns (address) {
        return user[account].ref;
    }

    function getUserRegistered(address account) public view returns (bool) {
        return user[account].registerd;
    }

    function getUserUpline(address account,uint256 level) public view returns (address[] memory) {
        address[] memory result = new address[](level);
        for(uint256 i=0; i<level; i++){
            result[i] = user[account].ref;
            account = user[account].ref;
        }
        return result;
    }

    function register(address referree,address referral) public forRole("permit") returns (bool) {
        if(!user[referree].registerd){
            users.push(referree);
            uint256 id = users.length-1;
            user[referree].id = id;
            user[referree].ref = referral;
            user[referree].registerd = true;
            Id2Address[id] = referree;
        }
        return true;
    }

    function updateHashtableWithPermit(address account,string memory key,uint256 value) public forRole("permit") returns (bool) {
        hashtable[account][key] = value; 
        return true;
    }

    function increaseHashtableWithPermit(address account,string memory key,uint256 value) public forRole("permit") returns (bool) {
        hashtable[account][key] += value; 
        return true;
    }

    function decreaseHashtableWithPermit(address account,string memory key,uint256 value) public forRole("permit") returns (bool) {
        hashtable[account][key] -= value; 
        return true;
    }

    function updateUserWithPermit(address account,uint256 id,address ref,bool registerd) public forRole("permit") returns (bool) {
        user[account].id = id;
        user[account].ref = ref;
        user[account].registerd = registerd;
        return true;
    }

    function updateUserReferreeWithPermit(address account,address[] memory refmap,uint256 level) public forRole("permit") returns (bool) {
        user[account].refmap[level] = refmap;
        return true;
    }

    function updateUserRefScoreWithPermit(address account,address[] memory refscore,uint256 cycle) public forRole("permit") returns (bool) {
        user[account].refscore[cycle] = refscore;
        return true;
    }

    function pushUserReferreeWithPermit(address referree,address referral,uint256 level) public forRole("permit") returns (bool) {
        user[referral].refmap[level].push(referree);
        return true;
    }

    function pushUserRefScoreWithPermit(address refscore,address referral,uint256 cycle) public forRole("permit") returns (bool) {
        user[referral].refscore[cycle].push(refscore);
        return true;
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