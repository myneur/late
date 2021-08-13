# export all/all columns > subscriptions.csv
# export ALL accesses > log.csv
# ignore scheduled cancels

import csv
from datetime import datetime
from datetime import timedelta
#import dateutil.parser as parser

accessLog = {} # get last access per subscription id
with open("../../log.csv") as csvfile:
		reader = csv.reader(csvfile, quoting=csv.QUOTE_NONE) 
		for row in reader: 
			if len(row[1])>10:
				accessLog[row[0]]= datetime.strptime(row[1], '%Y-%m-%d %H:%M:%S.%f+00')

subscriptions = {}	# get last access and all subscription ids per mail
with open("../../subscriptions.csv") as csvfile:
	reader = csv.reader(csvfile, quoting=csv.QUOTE_NONE) 
	for row in reader: 
		subid = row[0]
		if len(subid)<3:
			continue
		mail = row[3]
		status = row[8]
		started = row[9]
		try: 
			started = datetime.strptime(started, '%Y-%m-%d %H:%M')
		except:
			started = started.utcfromtimestamp(0)
		try: 
			lastAccess = accessLog[subid]
		except: 
			lastAccess = datetime.utcfromtimestamp(0) # when no data: start of epoch
		if mail in subscriptions.keys():
			subscriptions[mail]["subid"].append(subid)
			if subscriptions[mail]["lastAccess"] < lastAccess:
				subscriptions[mail]["lastAccess"] = lastAccess
		else:
			subscriptions[mail]={"subid": [subid], "lastAccess":lastAccess, "created": started, "status":status}

# 30 days considered dead
threshold = datetime.now()-timedelta(days=30)

# print outdated subscriptions' mails and ids
print( "STATUS: \tINACTIVE/DAYS \t[SUBSCRIPTIONS] \tMAIL ")
for k in subscriptions.keys():
	#print(subscriptions[s]["lastAccess"].strftime("%m/%d/%Y") + " " +s)
	v = subscriptions[k]
	if v["lastAccess"] < threshold:
		print(v["status"] +": \t"+ str((datetime.now()-v["lastAccess"]).days) + "/"+  str((datetime.now()-v["created"]).days) + " \t\t" + str((v["subid"])) + " \t" +k)

# list outdated mails only
for k in subscriptions.keys():
	#print(subscriptions[s]["lastAccess"].strftime("%m/%d/%Y") + " " +s)
	v = subscriptions[k]
	if v["lastAccess"] < threshold:
		print(k + ", ")

