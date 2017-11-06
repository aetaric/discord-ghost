CREATE TABLE `servers` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `sid` varchar(255) DEFAULT NULL,
  `limit_channels` tinyint(1) DEFAULT NULL,
  `channels` text,
  `d2_guild_id` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_servers_on_sid` (`sid`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8
