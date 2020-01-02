'use strict';
const
  Promise = require('bluebird'),
  AWS = require('aws-sdk');

AWS.config.update({
region: 'eu-west-2'
});

AWS.config.setPromisesDependency(Promise);

const ec2 = new AWS.EC2 ();

const rtParams = {
  Filters: [
    {
      Name: 'association.main',
      Values: [
        'false'
      ]
    }
  ]
};
const rts = async () => {
  return await ec2.describeRouteTables(rtParams).promise();
  /*const output = await ec2.describeRouteTables(rtParams).promise();
  return console.log(output);*/
  }
;
//console.log('all rts');
rts()
  .then(rts => {
    const vals = rts.RouteTables.map(rt => rt.RouteTableId);
    //return console.log(vals);
    return vals.forEach(id => console.log(id));
  })
  .catch(err => console.error(err));
    