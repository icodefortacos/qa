#!/bin/sh
#Asking user for database passwords
sudo echo "Please remember the following MySQL Root password"
read -s -p "Please enter a strong database password: " MYSQL_ROOT_PASSWORD
sudo echo ""
sudo echo "Thanks for inserting your Root Password for MySQL"

sudo echo "Please remember the following Jira Database password"
sudo echo "It will be required during the installation wizard"
read -s -p "Please enter a strong database password: " jiradb_PASSWORD
sudo echo ""
sudo echo "Thanks, your database name will be:"
sudo echo ""
sudo echo "jiradb"
sudo echo ""
sudo echo "Please be sure to remember this database name and password for it"

sudo apt-get update -y
sudo apt-get install expect fontconfig -y 

export DEBIAN_FRONTEND=noninteractive
echo debconf mysql-server/root_password password $MYSQL_ROOT_PASSWORD | sudo debconf-set-selections
echo debconf mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD | sudo debconf-set-selections
sudo apt-get  -qq install mysql-server -y > /dev/null

#Creating Jira database and database user
#SQL commands to be referenced later
SQL_COMMAND_1="CREATE DATABASE jiradb CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
SQL_COMMAND_2="CREATE USER 'jiradb'@'localhost' IDENTIFIED BY '${jiradb_PASSWORD}';"
SQL_COMMAND_3="GRANT ALL ON jiradb.* TO 'jiradb'@'localhost';"

#Create Jira Database and User
sudo echo "Configuring your jiradb Database now..."
mysql -u root -p$MYSQL_ROOT_PASSWORD << eof
$SQL_COMMAND_1
eof

mysql -u root -p$MYSQL_ROOT_PASSWORD << eof
$SQL_COMMAND_2
eof

mysql -u root -p$MYSQL_ROOT_PASSWORD << eof
$SQL_COMMAND_3
eof

tee ~/temp.sh > /dev/null << EOF
spawn $(which mysql_secure_installation)

expect "Enter password for user root:"
send "$MYSQL_ROOT_PASSWORD\r"

expect "Press y|Y for Yes, any other key for No:"
send "n\r"

expect "Change the password for root ? ((Press y|Y for Yes, any other key for No) :"
send "n\r"

expect "Remove anonymous users? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Disallow root login remotely? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Remove test database and access to it? (Press y|Y for Yes, any other key for No) :"
send "y\r"

expect "Reload privilege tables now? (Press y|Y for Yes, any other key for No) :"
send "y\r"

EOF

sudo expect ~/temp.sh
rm -v ~/temp.sh 

sudo cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOL
default-storage-engine=INNODB
character_set_server=utf8mb4
innodb_default_row_format=DYNAMIC
innodb_large_prefix=ON
innodb_file_format=Barracuda
innodb_log_file_size=2G
EOL

systemctl restart mysql

sudo wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-8.6.0-x64.bin
sudo chmod a+x atlassian-jira-software-8.6.0-x64.bin
sudo wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.48.tar.gz 
sudo tar -zxf mysql-connector-java-5.1.48.tar.gz
sudo mkdir -p /opt/atlassian/jira/lib/
sudo cp mysql-connector-java-5.1.48/mysql-connector-java-5.1.48* /opt/atlassian/jira/lib/
yes '' | ./atlassian-jira-software-8.6.0-x64.bin
