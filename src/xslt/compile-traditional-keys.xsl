<xsl:transform version="2.0"
               xmlns="http://www.w3.org/1999/XSL/TransformAlias"
               xmlns:sch="http://purl.oclc.org/dsdl/schematron"
               xmlns:schxslt="https://doi.org/10.5281/zenodo.1495494"
               xmlns:svrl="http://purl.oclc.org/dsdl/svrl"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:namespace-alias stylesheet-prefix="#default" result-prefix="xsl"/>
  <xsl:output indent="yes"/>

  <xsl:include href="compile/functions.xsl"/>
  <xsl:include href="compile/templates.xsl"/>
  <xsl:include href="compile/report.xsl"/>

  <xsl:param name="phase" as="xs:string">#DEFAULT</xsl:param>

  <xsl:variable name="effective-phase" select="schxslt:effective-phase(sch:schema, $phase)" as="xs:string"/>
  <xsl:variable name="active-patterns" select="schxslt:active-patterns(sch:schema, $effective-phase)" as="element(sch:pattern)+"/>

  <xsl:variable name="validation-stylesheet-body" as="element()+">
    <xsl:call-template name="schxslt:validation-stylesheet-body">
      <xsl:with-param name="patterns" as="element(sch:pattern)+" select="$active-patterns"/>
      <xsl:with-param name="bindings" as="element(sch:let)*" select="sch:schema/sch:phase[@id eq $effective-phase]/sch:let"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:template match="sch:schema">

    <transform version="2.0">
      <xsl:for-each select="sch:ns">
        <xsl:namespace name="{@prefix}" select="@uri"/>
      </xsl:for-each>
      <xsl:sequence select="@xml:base"/>

      <output indent="yes"/>

      <xsl:sequence select="xsl:key[not(preceding-sibling::sch:pattern)]"/>
      <xsl:sequence select="xsl:function[not(preceding-sibling::sch:pattern)]"/>

      <xsl:call-template name="schxslt:let-variable">
        <xsl:with-param name="bindings" select="sch:let"/>
      </xsl:call-template>

      <template match="/">
        <xsl:sequence select="sch:phase[@id eq $effective-phase]/@xml:base"/>

        <xsl:call-template name="schxslt:let-variable">
          <xsl:with-param name="bindings" select="sch:phase[@id eq $effective-phase]/sch:let"/>
        </xsl:call-template>

        <variable name="report" as="element(schxslt:report)">
          <schxslt:report>
            <xsl:variable name="bindings" as="element(xsl:with-param)*">
              <xsl:call-template name="schxslt:let-with-param">
                <xsl:with-param name="bindings" as="element(sch:let)*" select="sch:phase[@id eq $effective-phase]/sch:let"/>
              </xsl:call-template>
            </xsl:variable>
            <xsl:for-each select="$validation-stylesheet-body[self::xsl:template]/@name">
              <call-template name="{.}">
                <xsl:sequence select="$bindings"/>
              </call-template>
            </xsl:for-each>
          </schxslt:report>
        </variable>

        <xsl:call-template name="schxslt:process-report">
          <xsl:with-param name="report-variable-name" as="xs:string">report</xsl:with-param>
        </xsl:call-template>

        <xsl:call-template name="svrl:schematron-output">
          <xsl:with-param name="schema" as="element(sch:schema)" select="."/>
          <xsl:with-param name="phase" as="xs:string" select="$effective-phase"/>
          <xsl:with-param name="report-variable-name" as="xs:string">report</xsl:with-param>
        </xsl:call-template>

      </template>

      <template match="text() | @*" mode="#all" priority="-10"/>
      <template match="*" mode="#all" priority="-10">
        <apply-templates mode="#current" select="@* | node()"/>
      </template>

      <xsl:sequence select="$validation-stylesheet-body"/>
      <xsl:sequence select="document('compile/location.xsl')//xsl:function[@name = 'schxslt:location']"/>

    </transform>

  </xsl:template>

  <xsl:template name="schxslt:validation-stylesheet-body">
    <xsl:param name="patterns" as="element(sch:pattern)+"/>
    <xsl:param name="bindings" as="element(sch:let)*"/>

    <xsl:for-each select="$patterns">
      <xsl:variable name="mode" as="xs:string" select="generate-id()"/>

      <template name="{$mode}">
        <xsl:sequence select="@xml:base"/>

        <xsl:call-template name="schxslt:let-param">
          <xsl:with-param name="bindings" select="$bindings"/>
        </xsl:call-template>
        <xsl:call-template name="schxslt:let-variable">
          <xsl:with-param name="bindings" as="element(sch:let)*" select="sch:let"/>
        </xsl:call-template>

        <variable name="documents" as="item()+">
          <xsl:choose>
            <xsl:when test="@documents">
              <for-each select="{@documents}">
                <sequence select="document(.)"/>
              </for-each>
            </xsl:when>
            <xsl:otherwise>
              <sequence select="/"/>
            </xsl:otherwise>
          </xsl:choose>
        </variable>

        <for-each select="$documents">
          <xsl:call-template name="svrl:active-pattern">
            <xsl:with-param name="pattern" as="element(sch:pattern)" select="."/>
          </xsl:call-template>

          <apply-templates select="key('schxslt:rules', '{$mode}')" mode="{$mode}">
            <xsl:call-template name="schxslt:let-with-param">
              <xsl:with-param name="bindings" as="element(sch:let)*" select="sch:let"/>
            </xsl:call-template>
          </apply-templates>
        </for-each>

      </template>

      <xsl:apply-templates select="sch:rule">
        <xsl:with-param name="mode" as="xs:string" select="$mode"/>
        <xsl:with-param name="bindings" as="element(sch:let)*" select="($bindings, sch:let)"/>
      </xsl:apply-templates>

    </xsl:for-each>

  </xsl:template>

  <xsl:template match="sch:rule">
    <xsl:param name="mode" as="xs:string" required="yes"/>
    <xsl:param name="bindings" as="element(sch:let)*" required="yes"/>

    <key name="schxslt:rules" match="{@context}" use="'{$mode}'"/>

    <template match="{@context}" priority="{count(following-sibling::sch:rule)}" mode="{$mode}">
      <xsl:sequence select="(@xml:base, ../@xml:base)"/>

      <xsl:call-template name="schxslt:let-param">
        <xsl:with-param name="bindings" as="element(sch:let)*" select="$bindings"/>
      </xsl:call-template>

      <xsl:call-template name="schxslt:let-variable">
        <xsl:with-param name="bindings" as="element(sch:let)*" select="sch:let"/>
      </xsl:call-template>

      <xsl:call-template name="svrl:fired-rule">
        <xsl:with-param name="rule" as="element(sch:rule)" select="."/>
      </xsl:call-template>
      <xsl:apply-templates select="sch:assert | sch:report"/>

    </template>
  </xsl:template>

  <xsl:template name="schxslt:process-report">
    <xsl:param name="report-variable-name" as="xs:string" required="yes"/>
    <variable name="{$report-variable-name}">
      <sequence select="${$report-variable-name}/*"/>
    </variable>
  </xsl:template>

</xsl:transform>