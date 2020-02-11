# Concerto 2 Simple RSS Plugin
This plugin provides support to pull dynamic content from RSS and other XML feeds.

To install this plugin, go to the Plugin management page in concerto, select RubyGems as the source and "concerto_simple_rss" as the gem name.

Concerto 2 Simple RSS is licensed under the Apache License, Version 2.0.


## Example

Url: 
`https://w1.weather.gov/xml/current_obs/PASX.xml`

Display Format:
`XSLT`

Display Type:
`Ticker`

Reverse Order of Items:
`NO`

XSLT:

```
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <xsl:template match="/current_observation">
      <xsl:value-of select="./temperature_string"/>
      <xsl:value-of select="'. '"/>
      <xsl:value-of select="./weather"/> 
      <xsl:value-of select="'. '"/>
      <xsl:value-of select="./wind_string"/> 
      <xsl:value-of select="'. '"/>
  </xsl:template>
</xsl:stylesheet>
```
