import "../stylesheets/app.css";

// import Web3 from "web3";
import {
  default as Web3
} from 'web3';
import {
  default as contract
} from 'truffle-contract'
//var provider = new Web3.providers.HttpProvider("http://localhost:8545");
// var Web3EthContract = require('web3-eth-contract');

import ecommerce_store_artifacts from '../../build/contracts/EcommerceStore.json'
//var StandardEventJson = require("../../build/contracts/EcommerceStore.json");
//var EcommerceStore = new web3.eth.Contract(ecommerce_store_artifacts['abi'],'0xF4CEAE9a85623E35B5d10eeB6E7b15B5Fa98c16D');

const ipfsAPI = require('ipfs-api');
const ethUtil = require('ethereumjs-util');
// var address = "0x663951f04B0DFF5c0e338770f4ab28D73DC779cB";
// var EcommerceStore = new web3.eth.Contract(ecommerce_store_artifacts.abi,address);
var EcommerceStore = contract(ecommerce_store_artifacts);//['abi']
//EcommerceStore.setProvider(provider);


const ipfs = ipfsAPI({
  host: 'localhost',
  port: '5001',
  protocol: 'http'
});

window.App = {
  start: function() {
   web3.eth.defaultAccount = web3.eth.accounts[0];
    //console.log(window.web3.currentProvider);
    let self = this;

    EcommerceStore.setProvider(web3.currentProvider);

    renderStore()
    let reader;

    $("#product-image").change(function(event) {
      const file = event.target.files[0]
      reader = new window.FileReader()
      reader.readAsArrayBuffer(file)
    });

    $("#add-item-to-store").submit(function(event) {
      console.log("In add item to store");
      const req = $("#add-item-to-store").serialize();
      let params = JSON.parse('{"' + req.replace(/"/g, '\\"').replace(/&/g, '","').replace(/=/g, '":"') + '"}');
      let decodedParams = {};
      Object.keys(params).forEach(function(v) {
        decodedParams[v] = decodeURIComponent(decodeURI(params[v]));
      });
      saveProduct(reader, decodedParams);
      event.preventDefault();
    });

    $("#finalize-auction").submit(function(event) {
      $("#msg").hide();
      let productId = $("#product-id").val();
      EcommerceStore.deployed().then(function(i) {
        i.finalizeAuction(parseInt(productId), {
          from: web3.eth.accounts[0]
        }).then(
          function(f) {
            $("#msg").show();
            $("#msg").html("The auction has been finalized and winner declared.");
            console.log(f)
            location.reload();
          }
        ).catch(function(e) {
          console.log(e);
          $("#msg").show();
          $("#msg").html("The auction can not be finalized by the buyer or seller, only a third party aribiter can finalize it");
        })
      });
      event.preventDefault();
    });

    if ($("#product-details").length > 0) {
      console.log(window.location);
      console.log("Search Params = " + new URLSearchParams(window.location))
      let productId = new URLSearchParams(window.location.search).get('Id');
      console.log(productId);
      renderProductDetails(productId);
    }

    //拍卖报价
    $("#bidding").submit(function(event) {
      $("#msg").hide();
      let amount = $("#bid-amount").val();
      let sendAmount = $("#bid-send-amount").val();
      let secretText = $("#secret-text").val();
      console.log(web3.toWei(amount, 'ether'));
      //let sealedBid = '0x' + ethUtil.sha256(web3.toWei(amount, 'ether') + secretText).toString('hex');
      let sealedBid = '0x' + ethUtil.sha256(amount+ secretText).toString('hex');

      let productId = $("#product-id").val();
      // let userNumber = $("#user-number").val();
      // console.log(sealedBid + " for " + productId + " from user: " + userNumber);
      console.log(sealedBid + " for " + productId);

      EcommerceStore.deployed().then(function(i) {
        i.bid(parseInt(productId), sealedBid, {
          value: web3.toWei(sendAmount),
          from: web3.eth.accounts[0],
          gas: 440000
        }).then(
          function(f) {
            $("#msg").html("Your bid has been successfully submitted!");
            $("#msg").show();
            console.log(f)
          }
        )
      });
      event.preventDefault();
    });
    let elmo = function(me) {
      console.log("Doing BidCast");
      var self = me;
      EcommerceStore.deployed().then(function(i){i.bidCast().watch(function(error, result){
        console.log("In bidCast response.");
        if (error) {
          console.log(error);
        } else {
          for (var key in result) {
            if (result.hasOwnProperty(key)) {
              if (key !== "args") {
                   // console.log(key + " : " + result[key]);
              } else {
                let args = result["args"];
                  var message = "";
                  for (var arg in args) {

                    if (args.hasOwnProperty(arg)) {
                      var outcome = args[arg];
                      if (arg === 'value') {
                        outcome = web3.fromWei(outcome, 'ether');
                      }
                      message = message + " " + arg + ": " + outcome +  "   ";
                      //console.log("arg.. " + arg + ": " + outcome);
                    }
                  }
                  $("#msg2").show();
                  $("#msg2").html(message);
                }
              }
            }
          }
        })});
       };
       elmo(this);

    $("#revealing").submit(function(event) {
      $("#msg").hide();
      let amount = $("#actual-amount").val();
      let secretText = $("#reveal-secret-text").val();
      let productId = $("#product-id").val();
      // let userNumber = $("#reveal-user-number").val();
      EcommerceStore.deployed().then(function(i) {
        //i.revealBid(parseInt(productId), web3.toWei(amount,'ether').toString(), secretText, {
        i.revealBid(parseInt(productId), amount, secretText, {
          from: web3.eth.accounts[0],
          gas: 440000
        }).then(
          function(f) {
            $("#msg").show();
            $("#msg").html("Your bid has been successfully revealed!");
            console.log(f)
          }
        )
      });
      event.preventDefault();
    });
  },
};



function renderProductDetails(productId) {
  EcommerceStore.deployed().then(function(i) {
    i.getProduct.call(productId).then(function(p) {
      console.log(p);
      let content = "";
      ipfs.cat(p[4]).then(function(stream) {
        console.log(stream);
        stream.on('data', function(chunk) {
          // do stuff with this chunk of data
          content += chunk.toString();
          $("#product-desc").append("<div>" + content+ "</div>");
        })

        // console.log(stream);
        // let content = Utf8ArrayToStr(stream);
        // $("#product-desc").append("<div>" + content + "</div>");

      });

      $("#product-image").append("<img src='https://ipfs.io/ipfs/" + p[3] + "' width='250px' />");
      $("#product-price").html(displayPrice(p[7]));
      $("#product-name").html(p[1].name);
      $("#product-auction-end").html(displayEndHours(p[6]));
      $("#product-id").val(p[0]);
      $("#revealing, #bidding, #finalize-auction, #escrow-info").hide();
      let currentTime = getCurrentTimeInSeconds();
      if (parseInt(p[8]) == 1) {
        $("#product-status").html("Product sold");
      } else if (parseInt(p[8]) == 2) {
        $("#product-status").html("Product was not sold");
      } else if (currentTime < parseInt(p[6])) {
        $("#bidding").show();
      } else if (currentTime < (parseInt(p[6]) + 600)) {
        $("#revealing").show();
      } else {
        $("#finalize-auction").show();
      }
      if (p.productStatus == 1){
        EcommerceStore.deployed().then(function(i) {
          $("#escrow-info").show();
          i.highestBidderInfo.call(productId).then(function(f) {
            if (f[2].toLocaleString() == '0') {
              $("#product-status").html("Auction has ended. No bids were revealed");
            } else {
              $("#product-status").html("Auction has ended. Product sold to " + f[0] + " for " + displayPrice(f[2]) +
              "The money is in the escrow. Two of the three participants (Buyer, Seller and Arbiter) have to " +
              "either release the funds to seller or refund the money to the buyer");
            }
          })
          i.escrowInfo.call(productId).then(function(f) {
            $("#buyer").html('Buyer: ' + f[0]);
            $("#seller").html('Seller: ' + f[1]);
            $("#arbiter").html('Arbiter: ' + f[2]);
            if(f[3] == true) {
              $("#release-count").html("Amount from the escrow has been released");
            } else {
              $("#release-count").html(f[4] + " of 3 participants have agreed to release funds");
              $("#refund-count").html(f[5] + " of 3 participants have agreed to refund the buyer");
            }
          })
        })
      }
    })
  })
}


function Utf8ArrayToStr(array) {
  let out, i, len, c;
  let char2, char3;
  out = "";
  len = array.length;
  i = 0;
  while (i < len) {
    c = array[i++];
    switch (c >> 4) {
      case 0:
      case 1:
      case 2:
      case 3:
      case 4:
      case 5:
      case 6:
      case 7:
        // 0xxxxxxx
        out += String.fromCharCode(c);
        break;
      case 12:
      case 13:
        // 110x xxxx   10xx xxxx
        char2 = array[i++];
        out += String.fromCharCode(((c & 0x1F) << 6) | (char2 & 0x3F));
        break;
      case 14:
        // 1110 xxxx  10xx xxxx  10xx xxxx
        char2 = array[i++];
        char3 = array[i++];
        out += String.fromCharCode(((c & 0x0F) << 12) |
          ((char2 & 0x3F) << 6) |
          ((char3 & 0x3F) << 0));
        break;
      default:
        break;
    }
  }

  return out;
}



function getCurrentTimeInSeconds() {
  return Math.round(new Date() / 1000);
}

function displayPrice(amt) {
  return 'Ξ' + web3.fromWei(amt, 'ether');
}


function displayEndHours(seconds) {
  let current_time = getCurrentTimeInSeconds()
  let remaining_seconds = seconds - current_time;

  if (remaining_seconds <= 0) {
    return "Auction has ended";
  }

  let days = Math.trunc(remaining_seconds / (24 * 60 * 60));

  remaining_seconds -= days * 24 * 60 * 60
  let hours = Math.trunc(remaining_seconds / (60 * 60));

  remaining_seconds -= hours * 60 * 60

  let minutes = Math.trunc(remaining_seconds / 60);

  if (days > 0) {
    return "Auction ends in " + days + " days, " + hours + ", hours, " + minutes + " minutes";
  } else if (hours > 0) {
    return "Auction ends in " + hours + " hours, " + minutes + " minutes ";
  } else if (minutes > 0) {
    return "Auction ends in " + minutes + " minutes ";
  } else {
    return "Auction ends in " + remaining_seconds + " seconds";
  }
}


function saveProduct(reader, decodedParams) {
  let imageId, descId;
  saveImageOnIpfs(reader).then(function(id) {
    imageId = id;
    saveTextBlobOnIpfs(decodedParams["product-description"]).then(function(id) {
    descId = id;
    saveProductToBlockchain(decodedParams, imageId, descId);
    })
  })
}

function saveProductToBlockchain(params, imageId, descId) {

  let auctionStartTime = Date.parse(params["product-auction-start"]) / 1000;
  let auctionEndTime = auctionStartTime + parseInt(params["product-auction-end"]) * 24 * 60 * 60;
  console.log(EcommerceStore);
  EcommerceStore.deployed().then(function(i) {
    i.addProductToStore(params["product-name"], params["product-category"], imageId, descId, auctionStartTime,
      auctionEndTime, web3.toWei(params["product-price"], 'ether'), parseInt(params["product-condition"]),
       {
        from: web3.eth.accounts[0],
        gas: 623164
      }
    ).then(function(f) {
      console.log(f);
      $("#msg").show();
      $("#msg").html("Your product was successfully added to your store!");
    })
  });
}

function saveImageOnIpfs(reader) {
  return new Promise(function(resolve, reject) {
    const buffer = Buffer.from(reader.result);
    ipfs.add(buffer)
      .then((response) => {
        console.log(response)
        resolve(response[0].hash);
      }).catch((err) => {
        console.error(err)
        reject(err);
      })
  })
}

function saveTextBlobOnIpfs(blob) {
  return new Promise(function(resolve, reject) {
    const descBuffer = Buffer.from(blob, 'utf-8');
    ipfs.add(descBuffer)
      .then((response) => {
        console.log(response)
        resolve(response[0].hash);
      }).catch((err) => {
        console.error(err)
        reject(err);
      })
  })
}

function renderStore() {
  EcommerceStore.deployed().then(function(i) {

    i.productIndex().then((number) => {

      console.log("产品数量" + number);
      for (let k = 0; k < number; k++) {
        i.getProduct(k + 1).then(function(p) {
          $("#product-list").append(buildProduct(p, k + 1));
        });
      }
    });
  });
}

function buildProduct(product, id) {
  console.log("buildProduct");
  console.log(id);
  console.log(product);
  let node = $("<div/>");
  node.addClass("col-sm-3 text-center col-margin-bottom-1");
  node.append("<img src='http://localhost:8081/ipfs/" + product[3] + "' width='150px' />");
  node.append("<div>" + product[1] + "</div>");
  node.append("<div>" + product[2] + "</div>");
  node.append("<div>" + new Date(product[5] * 1000) + "</div>");
  node.append("<div>" + new Date(product[6] * 1000) + "</div>");
  node.append("<div>" + web3.fromWei(product[7],'ether') + " Ether</div>");
  node.append("<a href='product.html?Id=" + id + "'class='btn btn-primary'>查看</a>")
  return node;
};



window.addEventListener('load', function() {
  // if (typeof window.ethereum !== 'undefined') {
  //   let addr=await ethereum.request({ method: 'eth_requestAccounts' });//授权连接钱包
  //   console.log(\'用户钱包地址:\',addr[0]);
  //App.initWeb3();
  if (typeof web3 !== 'undefined') {
    console.warn("Using web3 detected from external source. If you find that your accounts don't appear or you have 0 MetaCoin, ensure you've configured that source properly. If using MetaMask, see the following link. Feel free to delete this warning. :) http://truffleframework.com/tutorials/truffle-and-metamask")
    window.web3 = new Web3(window.web3.currentProvider);

  } else {
    console.warn("No web3 detected. Falling back to http://localhost:8545. You should remove this fallback when you deploy live, as it's inherently insecure. Consider switching to Metamask for development. More info here: http://truffleframework.com/tutorials/truffle-and-metamask");
    this.web3.setProvider('http://localhost:8545');
    console.log("返回浏览器设置的原生 provider",this.web3.givenProvider);
    //window.web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));
  }
  App.start();
});
