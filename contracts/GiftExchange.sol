pragma solidity ^0.4.2;

contract Token {
  /// @return total amount of tokens
  function totalSupply() constant returns (uint256 supply) {}

  /// @param _owner The address from which the balance will be retrieved
  /// @return The balance
  function balanceOf(address _owner) constant returns (uint256 balance) {}

  /// @notice send _value token to _to from msg.sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transfer(address _to, uint256 _value) returns (bool success) {}

  /// @notice send _value token to _to from _from on the condition it is approved by _from
  /// @param _from The address of the sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return Whether the transfer was successful or not
  function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}

  /// @notice msg.sender approves _addr to spend _value tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @param _value The amount of wei to be approved for transfer
  /// @return Whether the approval was successful or not
  function approve(address _spender, uint256 _value) returns (bool success) {}

  /// @param _owner The address of the account owning tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @return Amount of remaining tokens allowed to spent
  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {}

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);

  uint public decimals;
  string public name;
}

contract GiftExchange is Token{
    uint public deposit;
    uint public timeUntillWithdraw;
    uint public creationTime;
    uint public numPlayers;
    uint public randShift;

    mapping(address => bool) allowedTokens;
    mapping(address => uint) playerDeposits;
    mapping(uint => address) giftAddress;
    mapping(uint => uint) giftSize;
    mapping(address => uint) playerNumber;

    enum Stages {
        OpenGame,
        WithdrawPeriod
    }

    //Tokens taken from https://etherscan.io/tokens. If you want to have a token
    //added to this list, please submit a Github issue (github.com/naterush).
    address[2] public tokens = [
        0xe0b7927c4af23765cb51314a0e0521a9645f0e2a, //DGD Token
        0xAf30D2a7E90d7DC361c8C4585e9BB7D2F6f15bc7, //FirstBlood
        0xa74476443119A942dE498590Fe1f2454d7D4aC0d, //Golem
        0x888666CA69E0f178DED6D75b5726Cee99A87D698, //ICONOMI
        0xc66ea802717bfb9833400264dd12c2bceaa34a6d, //MKR
        0xD8912C10681D8B21Fd3742244f44658dBA12264E, //Pluton
        0x48c80F1f4D53D5951e5D5438B54Cba84f29F32a5, //REP
        0xaec2e87e0a235266d9c5adc9deb4b2e29b54d009, //SNGLS
    ];

    Stages public stage;

    modifier atStage(Stages _stage) {
        if (_stage != stage) throw;
        _;
    }

    function nextStage() internal {
        //semi-protects random number generation
        if (tx.gasprice > 1,000,000,000 wei) throw;
        randShift = randomGen(numPlayers);
        stage = Stages(uint(stage) + 1);
    }

    modifier timedTransitions() {
        if (stage == Stages.OpenGame && now >= creationTime + timeUntillWithdraw) {
           nextStage();
        }
        _;
    }

    modifier savingAllowedERCTokens() {
         for (uint i=0; i < tokens.length; i++) {
             allowedTokens[tokens[i]] = true;
         }
         _;
     }

    //constructor
    function GiftExchange(uint _timeUntillWithdraw, uint _deposit) savingAllowedERCTokens() {
        creationTime = now;
        timeUntillWithdraw = _timeUntillWithdraw;
        deposit = _deposit;
        stage = Stages.OpenGame;
    }

    //make sure you call approve on the token contract you wish to gift.
    //parameters should be (addressOfThisContract, giftAmountInTokens).
    function joinExchange(address giftLocation, uint amount) timedTransitions() atStage(Stages.OpenGame) payable{
        //checks deposit, if token is real, and that token has been transfered
        if (msg.value != deposit) throw;
        if (!allowedTokens[giftLocation]) throw;
       	if (!Token(giftLocation).transferFrom(msg.sender, this, amount)) throw;
        //stores the token and token value
        giftAddress[numPlayers] = giftLocation;
        giftSize[numPlayers] = amount;
        playerNumber[msg.sender] = numPlayers;
        playerDeposits[msg.sender] = deposit;
        numPlayers++;
    }

    //if you are the first person to call this, or your transaction is failing
    //for an unknown reason, please lower your gas price (this is to semi-protect
    //pseudo-random number generation).
    function getGift() timedTransitions() atStage(Stages.WithdrawPeriod){
        //checks for player existance/functions as recursive protection
        if (playerDeposits[msg.sender] == 0) throw;
        //transfer the ~randomly selected token
        uint randGift = (playerNumber[msg.sender] + randShift) % numPlayers;
        if (!Token(giftAddress[randGift]).transfer(msg.sender, giftSize[randGift])) throw;
				//return deposit
        uint toSend = playerDeposits[msg.sender];
        playerDeposits[msg.sender] = 0;
        if (!msg.sender.send(toSend))
            throw;
        }


	  /* Generates a random number from 0 to size based on the last block hash */
    //taken from Alex Van de Sande github
    function randomGen(uint size) constant returns (uint randNum) {
        return (uint(sha3(block.blockhash(block.number - 1))) % size);
    }
}
