CREATE TABLE IF NOT EXISTS `cl_reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `report_info` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=170 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


CREATE TABLE IF NOT EXISTS `cl_reports_reset` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `last_reset` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `players`
ADD COLUMN `reports` INT(11) NULL DEFAULT NULL AFTER `last_updated`;
