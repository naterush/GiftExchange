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

    mapping(address => bool) allowedTokens;
    mapping(address => uint) playerDeposits;
    mapping(uint => address) giftAddress;
    mapping(uint => uint) giftSize;

    address[1] tokens;

    enum Stages {
        OpenGame,
        WithdrawPeriod
    }

    Stages public stage;

    modifier atStage(Stages _stage) {
        if (stage != _stage) throw;
        _;
    }

    function nextStage() internal {
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

    function GiftExchange(uint _timeUntillWithdraw, uint _deposit) savingAllowedERCTokens() {
        creationTime = now;
        timeUntillWithdraw = _timeUntillWithdraw;
        stage = Stages.OpenGame;
        deposit = _deposit;
        tokens[0] = 0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413;
    }

    function joinExchange(address giftLocation, uint amount) timedTransitions() atStage(Stages.OpenGame) payable{
        //checks deposit, if token is real, and that token has been sent
        if (msg.value != deposit) throw;
        if (!allowedTokens[giftLocation]) throw;
       	if (!Token(giftLocation).transferFrom(msg.sender, this, amount)) throw;

        giftAddress[numPlayers] = giftLocation;
        giftSize[numPlayers] = amount;
        numPlayers++;
        playerDeposits[msg.sender] = deposit;
    }

    function getGift() timedTransitions() atStage(Stages.WithdrawPeriod){
        if (playerDeposits[msg.sender] == 0) throw;
        //force a low gas price - this protects random number generation
        //as it allows for blocks to be generated inbetween transaction
        //and when its published on the blockchain, so there is no way of
        //guessing what the blockhashes will be when your transaction is
				//processed
        if (tx.gasprice > 10000 wei) throw;

        uint randNum = randomGen(numPlayers);
        //generates a random number based on some number of blocks
        //the number is between 0 and numPeopleInList - 1
        if (!Token(giftAddress[randNum]).transfer(msg.sender, giftSize[numPlayers])) throw;
        //update the end of the list, so this way gas costs are fair
        //and also do not have to spend gas moving values in array
        giftAddress[randNum] = giftAddress[numPlayers - 1];
        giftSize[randNum] = giftSize[numPlayers - 1];

				//return deposit
        uint toSend = playerDeposits[msg.sender];
        playerDeposits[msg.sender] = 0;
        if (!msg.sender.send(toSend))
            throw;
        }


	/* Generates a random number from 0 to 100 based on the last block hash */
    //taken from Alex Van de Sande github
    function randomGen(uint size) constant returns (uint randNum) {
        return (uint(sha3(block.blockhash(block.number - 1))) % size);
    }
}
