// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender,address recipient,uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; 
        return msg.data;
    }
}

contract Ownable is Context {
    
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

 
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }


    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0),"Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view virtual override returns (string memory) { return _name; }
    function symbol() public view virtual override returns (string memory) { return _symbol; }
    function decimals() public view virtual override returns (uint8) { return _decimals; }
    function totalSupply() public view virtual override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view virtual override returns (uint256) { return _balances[account]; }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender,address recipient,uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _allowances[sender][_msgSender()] -= amount;
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _allowances[_msgSender()][spender] += addedValue;
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _allowances[_msgSender()][spender] -= subtractedValue;
        return true;
    }

    function _transfer(address sender,address recipient,uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(sender, recipient, amount);
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _basictransfer(address sender,address recipient,uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        _totalSupply -= amount;
        _balances[account] -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner,address spender,uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from,address to,uint256 amount) internal virtual {}
}

contract RepeatsTokenTracker is ERC20, Ownable {

    string _name = "Repeats Token Tracker";
    string _symbol = "REPTT";
    uint8 _decimals = 6;
    uint256 _totalSupply = 0;

    bool linked;

    address public RepeatsRouter;

    address public DexPair;
    address public BurnWallet;

    constructor() ERC20(_name,_symbol,_decimals) {
        _mint(msg.sender, _totalSupply);
    }

    function updateDexPair(address account) public onlyOwner returns (bool) {
        DexPair = account;
        return true;
    }

    function updateBurnWallet(address account) public onlyOwner returns (bool) {
        BurnWallet = account;
        return true;
    }

    function settingRouter(address router) public onlyOwner returns (bool) {
        require(!linked,"Router Was Linked!");
        RepeatsRouter = router;
        return true;
    }

    function lockRouter() public onlyOwner returns (bool) {
        require(!linked,"Router Was Linked!");
        linked = true;
        return true;
    }

    function mint(address recipient, uint256 amount) public returns (bool) {
        require(msg.sender==RepeatsRouter,"RepeatsToken: Only RepeatsRouter Can Call!");
        _mint(recipient, amount);
        return true;
    }

    function burnFrom(address sender,uint256 amount) public returns (bool) {
        require(msg.sender==RepeatsRouter,"RepeatsToken: Only RepeatsRouter Can Call!");
        _burn(sender, amount);
        return true;
    }

    function updateRouter(address newRouter) public returns (bool) {
        require(msg.sender==RepeatsRouter,"RepeatsToken: Only RepeatsRouter Can Call!");
        RepeatsRouter = newRouter;
        return true;
    }

    function burn(uint256 amount) public returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 fees = 0;

        if (from==DexPair || to==DexPair) {
            fees = amount / 100;         
        }

        if (fees > 0) {
            super._transfer(from,BurnWallet,fees);
            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

}