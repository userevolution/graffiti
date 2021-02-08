//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

struct Account {
    int128 balance;
    uint64 taxBase;
    uint64 lastTaxPayment;
}

contract Graffiti is ERC721 {

    event Deposit(
        address account,
        uint64 amount,
        int128 balance
    );
    event Withdraw(
        address account,
        uint64 amount,
        int128 balance
    );
    event ColorChange(
        uint256 pixelID,
        uint8 color
    );
    event PriceChange(
        uint256 pixelID,
        uint64 price
    );
    event Buy(
        uint256 pixelID,
        address seller,
        address buyer,
        uint64 price
    );

    constructor(uint128 width, uint128 height) ERC721("Pixel", "PIX") {
        require(width > 0, "Graffiti: width must not be zero");
        require(height > 0, "Graffiti: height must not be zero");
        _maxPixelID = width * height - 1;
    }

    uint256 private _maxPixelID;

    mapping(uint256 => uint64) private _pixelPrices;
    mapping(address => Account) private _accounts;
    uint256 private _taxBalance;

    uint256 constant taxRateDenominator = 10;
    uint256 constant taxRateNumerator = 1;

    //
    // Pixel getters
    //
    function exists(uint256 pixelID) view public returns (bool) {
        return _exists(pixelID);
    }

    function getPrice(uint256 pixelID) view public returns (uint64) {
        if (!_exists(pixelID)) {
            return 0;
        }

        address owner = ownerOf(pixelID);
        if (getBalance(owner) <= 0) {
            return 0;
        }

        return _pixelPrices[pixelID];
    }

    function getMaxPixelID() view public returns (uint256) {
        return _maxPixelID;
    }

    //
    // Account getters
    //
    function getTaxBase(address account) view public returns (uint64) {
        return _accounts[account].taxBase;
    }

    function getLastTaxPayment(address account) view public returns (uint64) {
        return _accounts[account].lastTaxPayment;
    }

    function getBalance(address account) view public returns (int128) {
        Account memory acc = _accounts[account];
        uint64 unaccountedTax = _computeTax(acc.taxBase, acc.lastTaxPayment, uint64(block.timestamp));
        return _subInt128(acc.balance, unaccountedTax);
    }

    //
    // State updates
    //
    function buyPixel(uint256 pixelID, uint64 maxPrice, uint64 newPrice, uint8 color) public {
        uint64 price = getPrice(pixelID);
        require(price <= maxPrice, "Graffiti: pixel price exceeds max price");

        // pay taxes for buyer so that balance is up to date
        payTax(msg.sender);
        Account memory buyer = _accounts[msg.sender];

        // check that buyer has enough money to buy
        require(buyer.balance >= price, "Graffiti: balance too low");

        // reduce buyer's balance and increase buyer's tax base
        buyer.balance = _subInt128(buyer.balance, price);
        buyer.taxBase = _addUint64(buyer.taxBase, newPrice);

        _accounts[msg.sender] = buyer;

        address owner;
        if (_exists(pixelID)) {
            owner = ownerOf(pixelID);
            require(owner != msg.sender, "Graffiti: cannot buy pixel from yourself");

            // pay tax for seller so that balance is up to date
            payTax(owner);
            Account memory seller = _accounts[owner];

            // increase seller's balance and decrease seller's tax base
            seller.balance = _addInt128(seller.balance, price);
            seller.taxBase = _subUint64(seller.taxBase, price);

            _accounts[owner] = seller;
            _transfer(owner, msg.sender, pixelID);
        } else {
            owner = address(0);
            require(pixelID <= _maxPixelID, "Graffiti: max pixel ID exceeded");
            _mint(msg.sender, pixelID);
        }

        _pixelPrices[pixelID] = newPrice;

        emit Buy({
            pixelID: pixelID,
            seller: owner,
            buyer: msg.sender,
            price: price
        });
        emit ColorChange({
            pixelID: pixelID,
            color: color
        });
        emit PriceChange({
            pixelID: pixelID,
            price: newPrice
        });
    }

    function setColor(uint256 pixelID, uint8 color) public {
        require(_exists(pixelID), "Graffiti: pixel does not exist");
        address owner = ownerOf(pixelID);
        require(msg.sender == owner, "Graffiti: only pixel owner can set color");
        emit ColorChange({
            pixelID: pixelID,
            color: color
        });
    }

    function setPrice(uint256 pixelID, uint64 newPrice) public {
        require(_exists(pixelID));
        address owner = ownerOf(pixelID);
        require(msg.sender == owner, "Graffiti: only owner can set pixel price");

        payTax(msg.sender);
        Account memory account = _accounts[msg.sender];

        account.taxBase = _subUint64(account.taxBase, _pixelPrices[pixelID]);
        account.taxBase = _addUint64(account.taxBase, newPrice);

        _pixelPrices[pixelID] = newPrice;
        _accounts[msg.sender] = account;

        emit PriceChange({
            pixelID: pixelID,
            price: newPrice
        });
    }

    function payTax(address account) public {
        Account memory acc = _accounts[account];

        uint64 unaccountedTax = _computeTax(acc.taxBase, acc.lastTaxPayment, uint64(block.timestamp));
        if (unaccountedTax > 0 || acc.lastTaxPayment == 0) {
            acc.balance = _subInt128(acc.balance, unaccountedTax);
            acc.lastTaxPayment = uint64(block.timestamp);

            _accounts[account] = acc;
            _taxBalance += unaccountedTax;
        }
    }

    function deposit() payable public {
        payTax(msg.sender);
        Account memory account = _accounts[msg.sender];

        require(msg.value % (1 gwei) == 0, "Graffiti: deposit amount must be multiple of 1 GWei");
        uint64 amount = uint64(msg.value / (1 gwei));
        account.balance = _addInt128(account.balance, amount);

        _accounts[msg.sender] = account;
        emit Deposit({
            account: msg.sender,
            amount: amount,
            balance: account.balance
        });
    }

    function withdraw(uint64 amount) public {
        payTax(msg.sender);
        Account memory account = _accounts[msg.sender];

        require(account.balance >= amount);
        account.balance = _subInt128(account.balance, amount);

        (bool success,) = msg.sender.call{value: amount * (1 gwei)}("");
        require(success, "Graffiti: withdraw call reverted");
        _accounts[msg.sender] = account;
        emit Withdraw({
            account: msg.sender,
            amount: amount,
            balance: account.balance
        });
    }

    //
    // Helpers
    //
    function _addUint64(uint64 a, uint64 b) pure internal returns (uint64) {
        if (a <= type(uint64).max - b) {
            return a + b;
        } else {
            return type(uint64).max;
        }
    }

    function _subUint64(uint64 a, uint64 b) pure internal returns (uint64) {
        if (a >= b) {
            return a - b;
        } else {
            return 0;
        }
    }

    function _addInt128(int128 a, uint64 b) pure internal returns (int128) {
        if (a <= type(int128).max - b) {
            return a + b;
        } else {
            return type(int128).max;
        }
    }

    function _subInt128(int128 a, uint64 b) pure internal returns (int128) {
        if (a >= type(int128).min + b) {
            return a - b;
        } else {
            return type(int128).min;
        }
    }

    function _computeTax(uint64 taxBase, uint64 startTime, uint64 endTime) pure internal returns (uint64) {
        require(endTime >= startTime, "Graffiti: end time must be later than start time");
        uint256 num = uint256(endTime - startTime) * taxBase * taxRateNumerator;
        uint256 denom = 365 * 24 * 60 * 60 * taxRateDenominator;
        uint256 tax = num / denom;
        if (tax <= type(uint64).max) {
            return uint64(tax);
        } else {
            return type(uint64).max;
        }
    }

    //
    // Transfer overrides from ERC721
    //
    function transferFrom(address, address, uint256) public virtual override {
        assert(false); // transferring pixels is not possible
    }

    function safeTransferFrom(address, address, uint256) public virtual override {
        assert(false); // transferring pixels is not possible
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public virtual override {
        assert(false); // transferring pixels is not possible
    }
}
