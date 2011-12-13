<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna's
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent extends="extQueryCaching">

<!--- GET ALL RECORDS OF THIS TYPE IN A FOLDER --->
<cffunction name="getFolderAssets" access="public" description="GET ALL RECORDS OF THIS TYPE IN A FOLDER" output="false" returntype="query">
	<cfargument name="folder_id" type="string" required="true">
	<cfargument name="offset" type="numeric" required="false" default="0">
	<cfargument name="rowmaxpage" type="numeric" required="false" default="0">
	<cfargument name="thestruct" type="struct" required="false" default="">
	<!--- Set thestruct if not here --->
	<cfif NOT isstruct(arguments.thestruct)>
		<cfset arguments.thestruct = structnew()>
	</cfif>
	<!--- init local vars --->
	<cfset qLocal = 0>
	<!--- Set pages var --->
	<cfparam name="arguments.thestruct.pages" default="">
	<cfparam name="arguments.thestruct.thisview" default="">
	<!--- If we need to show subfolders --->
	<cfif session.showsubfolders EQ "T">
		<cfinvoke component="folders" method="getfoldersinlist" dsn="#variables.dsn#" folder_id="#arguments.folder_id#" hostid="#session.hostid#" database="#variables.database#" returnvariable="thefolders">
		<cfset thefolderlist = arguments.folder_id & "," & ValueList(thefolders.folder_id)>
	<cfelse>
		<cfset thefolderlist = arguments.folder_id & ",">
	</cfif>
	<!--- This is for Oracle and MSQL. Calculate the offset .Show the limit only if pages is null or current (from print) --->
	<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
		<cfif arguments.offset EQ 0>
			<cfset var min = 0>
			<cfset var max = arguments.rowmaxpage>
		<cfelse>
			<cfset var min = arguments.offset * arguments.rowmaxpage>
			<cfset var max = (arguments.offset + 1) * arguments.rowmaxpage>
			<cfif variables.database EQ "db2">
				<cfset min = min + 1>
			</cfif>
		</cfif>
	<cfelse>
		<cfset var min = 0>
		<cfset var max = 1000>
	</cfif>
	<!--- If there is a columnlist then take it else the default--->
	<cfif structkeyexists(arguments.thestruct,"columnlist")>
		<cfset thecolumns = arguments.thestruct.columnlist>
	<cfelse>
		<cfset thecolumns = "a.aud_id, a.aud_name, a.aud_extension, a.aud_create_date, a.aud_change_date, a.folder_id_r, a.is_available">
	</cfif>
	<!--- Oracle --->
	<cfif variables.database EQ "oracle">
		<!--- Clean columnlist --->
		<cfset var thecolumnlist = replacenocase(arguments.columnlist,"v.","","all")>
		<!--- Query --->
		<cfquery datasource="#Variables.dsn#" name="qLocal" cachename="aud#session.hostid#getFolderAssets#arguments.folder_id##arguments.offset##arguments.thestruct.thisview##arguments.thestruct.view##thecolumnlist##max#" cachedomain="#session.theuserid#_audios">
		SELECT rn, aud_id, aud_name, aud_extension, aud_create_date, aud_change_date, folder_id_r<cfif arguments.thestruct.view EQ "combined">,keywords, description</cfif>
		FROM (
			SELECT ROWNUM AS rn, aud_id, aud_name, aud_extension, aud_create_date, aud_change_date, folder_id_r<cfif arguments.thestruct.view EQ "combined">,keywords, description</cfif>
			FROM (
				SELECT #thecolumns#<cfif arguments.thestruct.view EQ "combined">,att.aud_keywords keywords, att.aud_description description</cfif>
				FROM #session.hostdbprefix#audios a<cfif arguments.thestruct.view EQ "combined"> LEFT JOIN #session.hostdbprefix#audios_text att ON a.aud_id = att.aud_id_r AND att.lang_id_r = 1</cfif>
				WHERE a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (a.aud_group IS NULL OR a.aud_group = '')
				AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				ORDER BY LOWER(a.aud_name) ASC
				)
			WHERE ROWNUM <= <cfqueryparam cfsqltype="cf_sql_numeric" value="#max#">
			)
		WHERE rn > <cfqueryparam cfsqltype="cf_sql_numeric" value="#min#">
		</cfquery>
	<!--- DB2 --->
	<cfelseif variables.database EQ "db2">
		<!--- Clean columnlist --->
		<cfset var thecolumnlist = replacenocase(arguments.columnlist,"v.","","all")>
		<!--- Query --->
		<cfquery datasource="#Variables.dsn#" name="qLocal" cachename="aud#session.hostid#getFolderAssets#arguments.folder_id##arguments.offset##arguments.thestruct.thisview##arguments.thestruct.view##thecolumnlist##max#" cachedomain="#session.theuserid#_audios">
		SELECT #thecolumnlist#<cfif arguments.thestruct.view EQ "combined">,att.aud_keywords keywords, att.aud_description description</cfif>
		FROM (
			SELECT row_number() over() as rownr, a.*<cfif arguments.thestruct.view EQ "combined">, att.*</cfif>
			FROM audios a<cfif arguments.thestruct.view EQ "combined"> LEFT JOIN #session.hostdbprefix#audios_text att ON a.aud_id = att.aud_id_r AND att.lang_id_r = 1</cfif>
			WHERE a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND (a.aud_group IS NULL OR a.aud_group = '')
			AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			<!--- Nirvanix and in Admin --->
			<cfif session.thisapp EQ "admin" AND application.razuna.storage EQ "nirvanix">
				AND lower(a.shared) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
			</cfif>
			ORDER BY LOWER(a.aud_name) ASC
		)
		<!--- Show the limit only if pages is null or current (from print) --->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			WHERE rownr between #min# AND #max#
		</cfif>
		</cfquery>
	<!--- Other DB's --->
	<cfelse>
		<!--- Calculate the offset --->
		<cfset var theoffset = arguments.offset * arguments.rowmaxpage>
		<!--- Query --->
		<cfquery datasource="#Variables.dsn#" name="qLocal" cachename="aud#session.hostid#getFolderAssets#arguments.folder_id##arguments.offset##arguments.thestruct.thisview##arguments.thestruct.view##thecolumns##max#" cachedomain="#session.theuserid#_audios">
		SELECT <cfif variables.database EQ "mssql" AND (arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current")>TOP #max# </cfif>
		#thecolumns#<cfif arguments.thestruct.view EQ "combined">,att.aud_keywords keywords, att.aud_description description</cfif>
		FROM #session.hostdbprefix#audios a<cfif arguments.thestruct.view EQ "combined"> LEFT JOIN #session.hostdbprefix#audios_text att ON a.aud_id = att.aud_id_r AND att.lang_id_r = 1</cfif>
		WHERE a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (a.aud_group IS NULL OR a.aud_group = '')
		AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<!--- Nirvanix and in Admin --->
		<cfif session.thisapp EQ "admin" AND application.razuna.storage EQ "nirvanix">
			AND lower(a.shared) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
		</cfif>
		<!--- MSSQL --->
		<cfif variables.database EQ "mssql" AND (arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current")>
			AND a.aud_id NOT IN (
				SELECT TOP #min# aud_id
				FROM #session.hostdbprefix#audios
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (aud_group IS NULL OR aud_group = '')
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			)
		</cfif>
		<!--- Show the limit only if pages is null or current (from print) --->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			<cfif variables.database EQ "mysql" OR variables.database EQ "h2">
				ORDER BY LOWER(a.aud_name) ASC
				LIMIT #theoffset#, #arguments.rowmaxpage#
			</cfif>
		</cfif>
		</cfquery>
	</cfif>
	<!--- Return --->
	<cfreturn qLocal />
</cffunction>

<!--- GET THE AUDIO DETAILS --->
<cffunction name="detail" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Params --->
	<cfset var qry = structnew()>
	<!--- Get details --->
	<cfquery datasource="#application.razuna.datasource#" name="details" cachename="aud#session.hostid#detail#arguments.thestruct.file_id#" cachedomain="#session.theuserid#_audios">
	SELECT a.aud_id, a.aud_name, a.folder_id_r, a.aud_extension, a.aud_online, a.aud_owner, a.cloud_url, a.cloud_url_org,
	a.aud_create_date, a.aud_create_time, a.aud_change_date, a.aud_change_time, a.aud_name_noext,
	a.aud_name_org, a.aud_name_org filenameorg, a.shared, a.aud_size, a.aud_meta, a.link_kind, a.link_path_url, 
	a.path_to_asset, a.lucene_key, s.set2_img_download_org, s.set2_intranet_gen_download, s.set2_url_website,
	u.user_first_name, u.user_last_name, fo.folder_name
	FROM #session.hostdbprefix#audios a 
	LEFT JOIN #session.hostdbprefix#settings_2 s ON s.set2_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#application.razuna.setid#"> AND s.host_id = a.host_id
	LEFT JOIN users u ON u.user_id = a.aud_owner
	LEFT JOIN #session.hostdbprefix#folders fo ON fo.folder_id = a.folder_id_r AND fo.host_id = a.host_id
	WHERE a.aud_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
	AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Get descriptions and keywords --->
	<cfquery datasource="#application.razuna.datasource#" name="desc" cachename="aud#session.hostid#detaildesc#arguments.thestruct.file_id#" cachedomain="#session.theuserid#_audios">
	SELECT aud_description, aud_keywords, lang_id_r
	FROM #session.hostdbprefix#audios_text
	WHERE aud_id_r = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<!--- Convert the size --->
	<cfinvoke component="global" method="converttomb" returnvariable="thesize" thesize="#details.aud_size#">
	<!--- Put into struct --->
	<cfset qry.detail = details>
	<cfset qry.desc = desc>
	<cfset qry.thesize = thesize>
	<!--- <cfset qry.theprevsize = theprevsize> --->
	<!--- Return --->
	<cfreturn qry>
</cffunction>

<!--- UPDATE AUDIOS IN THREAD --->
<cffunction name="update" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Set arguments --->
	<cfset arguments.thestruct.dsn = variables.dsn>
	<cfset arguments.thestruct.setid = variables.setid>
	<!--- <cfinvoke method="updatethread" thestruct="#arguments.thestruct#" /> --->
	<!--- Start the thread for updating --->
	<cfset tt = CreateUUid()>
	<cfthread name="update#tt#" intstruct="#arguments.thestruct#">
		<cfinvoke method="updatethread" thestruct="#attributes.intstruct#" />
	</cfthread>
</cffunction>

<!--- SAVE THE AUDIO DETAILS --->
<cffunction name="updatethread" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Params --->
	<cfparam name="arguments.thestruct.shared" default="F">
	<cfparam name="arguments.thestruct.what" default="">
	<cfparam name="arguments.thestruct.aud_online" default="F">
	<cfparam name="arguments.thestruct.frombatch" default="F">
	<!--- Loop over the file_id (important when working on more then one image) --->
	<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="i">
	<cfset i = listfirst(i,"-")>
	<cfset arguments.thestruct.file_id = i>
		<!--- Save the desc and keywords --->
		<cfloop list="#arguments.thestruct.langcount#" index="langindex">
		<!--- If we come from all we need to change the desc and keywords arguments name --->
			<cfif arguments.thestruct.what EQ "all">
				<cfset alldesc = "all_desc_" & #langindex#>
				<cfset allkeywords = "all_keywords_" & #langindex#>
				<cfset thisdesc = "arguments.thestruct.aud_desc_" & #langindex#>
				<cfset thiskeywords = "arguments.thestruct.aud_keywords_" & #langindex#>
				<cfset "#thisdesc#" =  evaluate(alldesc)>
				<cfset "#thiskeywords#" =  evaluate(allkeywords)>
			<cfelse>
				<cfset thisdesc="aud_desc_" & #langindex#>
				<cfset thiskeywords="aud_keywords_" & #langindex#>	
			</cfif>
			<cfset l = #langindex#>
			<cfif thisdesc CONTAINS #l# OR thiskeywords CONTAINS #l#>
				<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="f">
					<cfquery datasource="#variables.dsn#" name="ishere">
					SELECT aud_id_r
					FROM #session.hostdbprefix#audios_text
					WHERE aud_id_r = <cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">
					AND lang_id_r = <cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">
					</cfquery>
					<cfif #ishere.recordcount# IS NOT 0>
						<cfquery datasource="#variables.dsn#">
						UPDATE #session.hostdbprefix#audios_text
						SET 
						aud_description = <cfqueryparam value="#ltrim(evaluate(thisdesc))#" cfsqltype="cf_sql_varchar">, 
						aud_keywords = <cfqueryparam value="#ltrim(evaluate(thiskeywords))#" cfsqltype="cf_sql_varchar">
						WHERE aud_id_r = <cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">
						AND lang_id_r = <cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">
						</cfquery>
					<cfelse>
						<cfquery datasource="#variables.dsn#">
						INSERT INTO #session.hostdbprefix#audios_text
						(id_inc, aud_id_r, lang_id_r, aud_description, aud_keywords, host_id)
						VALUES(
						<cfqueryparam value="#createuuid()#" cfsqltype="CF_SQL_VARCHAR">,
						<cfqueryparam value="#f#" cfsqltype="CF_SQL_VARCHAR">, 
						<cfqueryparam value="#l#" cfsqltype="cf_sql_numeric">, 
						<cfqueryparam value="#ltrim(evaluate(thisdesc))#" cfsqltype="cf_sql_varchar">, 
						<cfqueryparam value="#ltrim(evaluate(thiskeywords))#" cfsqltype="cf_sql_varchar">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
						)
						</cfquery>
					</cfif>
				</cfloop>
			</cfif>
		</cfloop>
		<!--- Save to the files table --->
		<cfif structkeyexists(arguments.thestruct,"file_name") AND arguments.thestruct.frombatch NEQ "T">
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#audios
			SET
			aud_name = <cfqueryparam value="#arguments.thestruct.file_name#" cfsqltype="cf_sql_varchar">,
			aud_online = <cfqueryparam value="#arguments.thestruct.aud_online#" cfsqltype="cf_sql_varchar">,
			shared = <cfqueryparam value="#arguments.thestruct.shared#" cfsqltype="cf_sql_varchar">,
			aud_change_date = <cfqueryparam value="#now()#" cfsqltype="cf_sql_date">,
			aud_change_time = <cfqueryparam value="#now()#" cfsqltype="cf_sql_timestamp">
			WHERE aud_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
		<cfquery datasource="#variables.dsn#" name="qryorg">
		SELECT aud_name_org, aud_name, path_to_asset
		FROM #session.hostdbprefix#audios
		WHERE aud_id = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Select the record to get the original filename or assign if one is there --->
		<cfif NOT structkeyexists(arguments.thestruct,"filenameorg") OR arguments.thestruct.filenameorg EQ "">
			<cfset arguments.thestruct.qrydetail.filenameorg = qryorg.aud_name_org>
			<cfset arguments.thestruct.file_name = qryorg.aud_name>
		<cfelse>
			<cfset arguments.thestruct.qrydetail.filenameorg = arguments.thestruct.filenameorg>
		</cfif>
		<!--- Nirvanix: Set Shared on this asset and all related ones
		<cfif application.razuna.storage EQ "nirvanix" AND arguments.thestruct.link_kind NEQ "url">
			<!--- Get all related records --->
			<cfquery datasource="#variables.dsn#" name="qry">
			SELECT folder_id_r, aud_id theid, aud_name_org thefilename, path_to_asset
			FROM #session.hostdbprefix#audios
			WHERE aud_group = <cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif> --->
		<!--- Lucene --->
		<cfset arguments.thestruct.qrydetail.folder_id_r = arguments.thestruct.folder_id>
		<cfset arguments.thestruct.qrydetail.path_to_asset = qryorg.path_to_asset>
		<!--- Local --->
		<cfif application.razuna.storage EQ "local">
			<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="aud">
			<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="aud" online="#arguments.thestruct.aud_online#">
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage EQ "nirvanix" OR application.razuna.storage EQ "amazon">
			<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="aud" notfile="T">
			<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.file_id#" category="aud" online="#arguments.thestruct.aud_online#" notfile="T">
		</cfif>
		<!--- Log --->
		<cfset log = #log_assets(theuserid=session.theuserid,logaction='Update',logdesc='Updated: #arguments.thestruct.file_name#',logfiletype='aud')#>
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_audios" />
	</cfloop>
	
</cffunction>

<!--- REMOVE THE AUDIO --->
<cffunction name="removeaudio" output="false" access="public">
	<cfargument name="thestruct" type="struct">
	<!--- Get file detail for log --->
	<cfquery datasource="#application.razuna.datasource#" name="details">
	SELECT aud_name, folder_id_r, link_kind, link_path_url, aud_name_org filenameorg, lucene_key, path_to_asset
	FROM #session.hostdbprefix#audios
	WHERE aud_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Log --->
	<cfinvoke component="extQueryCaching" method="log_assets">
		<cfinvokeargument name="theuserid" value="#session.theuserid#">
		<cfinvokeargument name="logaction" value="Delete">
		<cfinvokeargument name="logdesc" value="Removed: #details.aud_name#">
		<cfinvokeargument name="logfiletype" value="aud">
	</cfinvoke>
	<!--- Delete from files DB (including referenced data)--->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#audios
	WHERE aud_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Delete from collection --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#collections_ct_files
	WHERE file_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND col_file_type = <cfqueryparam value="aud" cfsqltype="cf_sql_varchar">
	</cfquery>
	<!--- Delete from favorites --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#users_favorites
	WHERE fav_id = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND fav_kind = <cfqueryparam value="aud" cfsqltype="cf_sql_varchar">
	AND user_id_r = <cfqueryparam value="#session.theuserid#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<!--- Delete from Versions --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#versions
	WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	AND ver_type = <cfqueryparam value="aud" cfsqltype="cf_sql_varchar">
	</cfquery>
	<!--- Delete from Share Options --->
	<cfquery datasource="#application.razuna.datasource#">
	DELETE FROM #session.hostdbprefix#share_options
	WHERE asset_id_r = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<!--- Delete labels --->
	<cfinvoke component="labels" method="label_ct_remove" id="#arguments.thestruct.id#" />
	<!--- Delete from file system --->
	<cfset tt = CreateUUid()>
	<cfset arguments.thestruct.hostid = session.hostid>
	<cfset arguments.thestruct.folder_id_r = details.folder_id_r>
	<cfset arguments.thestruct.qrydetail = details>
	<cfset arguments.thestruct.link_kind = details.link_kind>
	<cfset arguments.thestruct.filenameorg = details.filenameorg>
	<cfthread name="del#tt#" intstruct="#arguments.thestruct#">
		<cfinvoke method="deletefromfilesystem" thestruct="#attributes.intstruct#">
	</cfthread>
	<!--- Flush Cache --->
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_audios" />
	<cfreturn />
</cffunction>

<!--- REMOVE MANY AUDIOS --->
<cffunction name="removeaudiomany" output="false" access="public">
	<cfargument name="thestruct" type="struct">
	<!--- Set Params --->
	<cfset session.hostdbprefix = arguments.thestruct.hostdbprefix>
	<cfset session.hostid = arguments.thestruct.hostid>
	<cfset session.theuserid = arguments.thestruct.theuserid>
	<!--- Loop --->
	<cfloop list="#arguments.thestruct.id#" index="i" delimiters=",">
		<!--- Get file detail for log --->
		<cfquery datasource="#application.razuna.datasource#" name="thedetail">
		SELECT aud_name, folder_id_r, aud_name_org, aud_name_org filenameorg, link_kind, link_path_url, path_to_asset, lucene_key
		FROM #arguments.thestruct.hostdbprefix#audios
		WHERE aud_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
		</cfquery>
		<!--- Log --->
		<cfinvoke component="extQueryCaching" method="log_assets">
			<cfinvokeargument name="theuserid" value="#arguments.thestruct.theuserid#">
			<cfinvokeargument name="logaction" value="Delete">
			<cfinvokeargument name="logdesc" value="Removed: #thedetail.aud_name#">
			<cfinvokeargument name="logfiletype" value="aud">
		</cfinvoke>
		<!--- Delete from files DB (including referenced data)--->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #arguments.thestruct.hostdbprefix#audios
		WHERE aud_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
		</cfquery>
		<!--- Delete from collection --->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #arguments.thestruct.hostdbprefix#collections_ct_files
		WHERE file_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
		AND col_file_type = <cfqueryparam value="aud" cfsqltype="cf_sql_varchar">
		</cfquery>
		<!--- Delete from favorites --->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #arguments.thestruct.hostdbprefix#users_favorites
		WHERE fav_id = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
		AND fav_kind = <cfqueryparam value="aud" cfsqltype="cf_sql_varchar">
		AND user_id_r = <cfqueryparam value="#arguments.thestruct.theuserid#" cfsqltype="CF_SQL_VARCHAR">
		</cfquery>
		<!--- Delete from Versions --->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #arguments.thestruct.hostdbprefix#versions
		WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
		AND ver_type = <cfqueryparam value="aud" cfsqltype="cf_sql_varchar">
		</cfquery>
		<!--- Delete from Share Options --->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #arguments.thestruct.hostdbprefix#share_options
		WHERE asset_id_r = <cfqueryparam value="#i#" cfsqltype="CF_SQL_VARCHAR">
		</cfquery>
		<!--- Delete labels --->
		<cfinvoke component="labels" method="label_ct_remove" id="#i#" />
		<!--- Delete from file system --->
		<cfset tt = CreateUUid()>
		<cfset arguments.thestruct.id = i>
		<cfset arguments.thestruct.folder_id_r = thedetail.folder_id_r>
		<cfset arguments.thestruct.qrydetail = thedetail>
		<cfset arguments.thestruct.link_kind = thedetail.link_kind>
		<cfset arguments.thestruct.filenameorg = thedetail.filenameorg>
		<cfthread name="del#tt#" intstruct="#arguments.thestruct#">
			<cfinvoke method="deletefromfilesystem" thestruct="#attributes.intstruct#">
		</cfthread>
	</cfloop>
	<!--- Flush Cache --->
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#arguments.thestruct.theuserid#_audios" />
	<cfreturn />
</cffunction>

<!--- SubFunction called from deletion above --->
<cffunction name="deletefromfilesystem" output="false">
	<cfargument name="thestruct" type="struct">
	<cftry>
		<!--- Delete in Lucene --->
		<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#arguments.thestruct.id#" category="aud">
		<!--- Delete File --->
		<cfif application.razuna.storage EQ "local">
			<cfif DirectoryExists("#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#arguments.thestruct.qrydetail.path_to_asset#") AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
				<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#arguments.thestruct.qrydetail.path_to_asset#" recurse="true">
			</cfif>
			<!--- Versions --->
			<cfif DirectoryExists("#arguments.thestruct.assetpath#/#session.hostid#/versions/aud/#arguments.thestruct.id#") AND arguments.thestruct.id NEQ "">
				<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#session.hostid#/versions/aud/#arguments.thestruct.id#" recurse="true">
			</cfif>
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage EQ "nirvanix" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
			<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/#arguments.thestruct.qrydetail.path_to_asset#">
			<!--- Versions --->
			<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/versions/aud/#arguments.thestruct.id#">
		<!--- Amazon --->
		<cfelseif application.razuna.storage EQ "amazon" AND arguments.thestruct.qrydetail.path_to_asset NEQ "">
			<cfinvoke component="amazon" method="deletefolder" folderpath="#arguments.thestruct.qrydetail.path_to_asset#" awsbucket="#arguments.thestruct.awsbucket#" />
			<!--- Versions --->
			<cfinvoke component="amazon" method="deletefolder" folderpath="versions/aud/#arguments.thestruct.id#" awsbucket="#arguments.thestruct.awsbucket#" />
		</cfif>
		<!--- REMOVE RELATED FOLDERS ALSO!!!! --->
		<!--- Get all that have the same vid_id as related --->
		<cfquery datasource="#application.razuna.datasource#" name="qry">
		SELECT path_to_asset
		FROM #session.hostdbprefix#audios
		WHERE aud_group = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Loop over the found records --->
		<cfloop query="qry">
			<cftry>
				<cfif application.razuna.storage EQ "local">
					<cfif DirectoryExists("#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#path_to_asset#") AND path_to_asset NEQ "">
						<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#arguments.thestruct.hostid#/#path_to_asset#" recurse="true">
					</cfif>
				<cfelseif application.razuna.storage EQ "nirvanix" AND path_to_asset NEQ "">
					<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/#path_to_asset#">
				<cfelseif application.razuna.storage EQ "amazon" AND path_to_asset NEQ "">
					<cfinvoke component="amazon" method="deletefolder" awsbucket="#arguments.thestruct.awsbucket#" folderpath="#path_to_asset#">
				</cfif>
				<cfcatch type="any"></cfcatch>
			</cftry>
		</cfloop>
		<!--- Delete related videos as well --->
		<cfquery datasource="#application.razuna.datasource#">
		DELETE FROM #session.hostdbprefix#audios
		WHERE aud_group = <cfqueryparam value="#arguments.thestruct.id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<cfcatch type="any">
			<cfinvoke component="debugme" method="email_dump" emailto="support@razuna.com" emailfrom="server@razuna.com" emailsubject="Error on removing a audio from system (HostID: #arguments.thestruct.hostid#, Asset: #arguments.thestruct.id#)" dump="#cfcatch#">
		</cfcatch>
	</cftry>
	<cfreturn />
</cffunction>

<!--- MOVE FILE IN THREADS --->
<cffunction name="movethread" output="false">
	<cfargument name="thestruct" type="struct">
		<cfloop list="#arguments.thestruct.file_id#" delimiters="," index="fileid">
			<cfset arguments.thestruct.aud_id = "">
			<!--- If we are coming from a overview ids come with type --->
			<cfif arguments.thestruct.thetype EQ "all" AND fileid CONTAINS "-aud">
				<cfset arguments.thestruct.aud_id = listfirst(fileid,"-")>
			<cfelseif arguments.thestruct.thetype NEQ "all">
				<cfset arguments.thestruct.aud_id = fileid>
			</cfif>
			<cfif arguments.thestruct.aud_id NEQ "">
				<!--- <cfinvoke method="move" thestruct="#arguments.thestruct#" /> --->
				<cfset tt = CreateUUid()>
				<cfthread name="#tt#" intstruct="#arguments.thestruct#">
					<cfinvoke method="move" thestruct="#attributes.intstruct#" />
				</cfthread>
			</cfif>
		</cfloop>
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_audios" />
</cffunction>

<!--- MOVE FILE --->
<cffunction name="move" output="false">
	<cfargument name="thestruct" type="struct">
		<cftry>
			<cfset arguments.thestruct.qryaud = "">
			<!--- Move --->
			<cfset arguments.thestruct.file_id = arguments.thestruct.aud_id>
			<cfinvoke method="detail" thestruct="#arguments.thestruct#" returnvariable="qrydetails">
			<cfset arguments.thestruct.qryaud = qrydetails.detail>
			<!--- Ignore if the folder id is the same --->
			<cfif arguments.thestruct.folder_id NEQ arguments.thestruct.qryaud.folder_id_r>
				<!--- Update DB --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#audios
				SET folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
				WHERE aud_id = <cfqueryparam value="#arguments.thestruct.aud_id#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>			
				<!--- MOVE ALL RELATED FOLDERS TOO!!!!!!! --->
				<cfinvoke method="moverelated" thestruct="#arguments.thestruct#">
				<!--- Log --->
				<cfset log = #log_assets(theuserid=session.theuserid,logaction='Move',logdesc='Moved: #arguments.thestruct.qryaud.aud_name#',logfiletype='aud')#>
			</cfif>
			<cfcatch type="any">
				<cfinvoke component="debugme" method="email_dump" emailto="support@razuna.com" emailfrom="server@razuna.com" emailsubject="error in moving audio" dump="#cfcatch#">
			</cfcatch>
		</cftry>
	<cfreturn />
</cffunction>

<!--- Move related videos --->
<cffunction name="moverelated" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Get all that have the same aud_id as related --->
	<cfquery datasource="#variables.dsn#" name="qryintern">
	SELECT folder_id_r, aud_id
	FROM #session.hostdbprefix#audios
	WHERE aud_group = <cfqueryparam value="#arguments.thestruct.aud_id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Loop over the found records --->
	<cfif qryintern.recordcount NEQ 0>
		<cfloop query="qryintern">
			<!--- Update DB --->
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#audios
			SET folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			WHERE aud_id = <cfqueryparam value="#aud_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfloop>
	</cfif>
	<cfreturn />
</cffunction>

<!--- GET THE VIDEO DETAILS FOR BASKET --->
<cffunction name="detailforbasket" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Param --->
	<cfparam default="F" name="arguments.thestruct.related">
	<!--- Qry. We take the query and do a IN --->
	<cfquery datasource="#variables.dsn#" name="qry" cachename="aud#session.hostid#detailforbasket#ValueList(arguments.thestruct.qrybasket.cart_product_id)##arguments.thestruct.related#" cachedomain="#session.theuserid#_audios">
	SELECT aud_id, aud_name, aud_extension, aud_group, folder_id_r, aud_size, link_kind, link_path_url, path_to_asset
	FROM #session.hostdbprefix#audios
	WHERE 
	<cfif arguments.thestruct.related EQ "T">
		aud_group
	<cfelse>
		aud_id
	</cfif>
	<cfif arguments.thestruct.qrybasket.recordcount EQ 0>
	= '0'
	<cfelse>
	IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.thestruct.qrybasket.cart_product_id)#" list="true">)
	</cfif>
	</cfquery>
	<cfreturn qry>
</cffunction>

<!--- CONVERT AUDIO IN A THREAD --->
<cffunction name="convertaudiothread" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- RFS --->
	<cfif application.razuna.renderingfarm>
		<cfset arguments.thestruct.convert = true>
		<cfset arguments.thestruct.assettype = "aud">
		<cfthread intstruct="#arguments.thestruct#">
			<cfinvoke component="rfs" method="notify" thestruct="#attributes.intstruct#" />
		</cfthread>
	<cfelse>
		<!--- Start the thread for converting --->
		<cfthread intstruct="#arguments.thestruct#">
			<cfinvoke method="convertaudio" thestruct="#attributes.intstruct#" />
		</cfthread>
	</cfif>
</cffunction>

<!--- CONVERT AUDIO --->
<cffunction name="convertaudio" output="true">
	<cfargument name="thestruct" type="struct">
	<cftry>
		<!--- Param --->
		<cfparam name="fromadmin" default="F">
		<cfset arguments.thestruct.dsn = application.razuna.datasource>
		<cfset arguments.thestruct.setid = application.razuna.setid>
		<cfset arguments.thestruct.hostid = session.hostid>
		<cfset cloud_url_org.theurl = "">
		<cfset cloud_url.theurl = "">
		<cfset cloud_url_2.theurl = "">
		<cfset cloud_url_org.newepoch = 0>
		<cfparam name="arguments.thestruct.upl_template" default="0">		
		<!--- Get Tools --->
		<cfinvoke component="settings" method="get_tools" returnVariable="arguments.thestruct.thetools" />
		<!--- Go grab the platform --->
		<cfinvoke component="assets" method="iswindows" returnvariable="iswindows">
		<!--- Get details --->
		<cfinvoke method="detail" thestruct="#arguments.thestruct#" returnvariable="arguments.thestruct.qry_detail">
		<!--- Create a temp directory to hold the video file (needed because we are doing other files from it as well) --->
		<cfset tempfolder = "aud#replace(createuuid(),"-","","all")#">
		<!--- set the folder path in a var --->
		<cfset thisfolder = "#arguments.thestruct.thepath#/incoming/#tempfolder#">
		<!--- Create the temp folder in the incoming dir --->
		<cfdirectory action="create" directory="#thisfolder#" mode="775">
		<!--- Set vars for thread --->
		<cfset arguments.thestruct.thisfolder = thisfolder>
		<!--- Get name without extension --->
		<cfset arguments.thestruct.thenamenoext = listfirst(arguments.thestruct.qry_detail.detail.aud_name_org, ".")>
		<!--- Local --->
		<cfif application.razuna.storage EQ "local" AND arguments.thestruct.link_kind NEQ "lan">
			<!--- Now get the extension and the name after the position from above --->
			<cfset arguments.thestruct.thename = arguments.thestruct.qry_detail.detail.aud_name_org>
			<!--- Check to see if original file is in WAV format if so take it else take the WAV one --->
			<cfif arguments.thestruct.qry_detail.detail.aud_extension EQ "WAV">
				<!--- Set the input path --->
				<cfset inputpath = "#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qry_detail.detail.path_to_asset#/#arguments.thestruct.qry_detail.detail.aud_name_org#">
			<cfelse>
				<cfset inputpath = "#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qry_detail.detail.path_to_asset#/#arguments.thestruct.qry_detail.detail.aud_name_noext#.wav">
			</cfif>
			<cfthread name="convert#arguments.thestruct.file_id#" />
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage EQ "nirvanix" AND arguments.thestruct.link_kind NEQ "lan">
			<!--- For wget script --->
			<cfset var wgetscript = replace(createuuid(),"-","","all")>
			<cfset arguments.thestruct.theshw = GetTempDirectory() & "/#wgetscript#w.sh">
			<cfset var thewget = "#arguments.thestruct.thetools.wget#/wget">
			<!--- On Windows a .bat --->
			<cfif iswindows>
				<cfset arguments.thestruct.theshw = GetTempDirectory() & "/#wgetscript#w.bat">
				<cfset var thewget = """#arguments.thestruct.thetools.wget#/wget.exe""">
			</cfif>
			<!--- Check to see if original file is in WAV format if so take it else take the WAV one --->
			<cfif arguments.thestruct.qry_detail.detail.aud_extension EQ "WAV">
				<!--- Write --->	
				<cffile action="write" file="#arguments.thestruct.theshw#" output="#thewget# -P #arguments.thestruct.thisfolder# #arguments.thestruct.qry_detail.detail.cloud_url_org#" mode="777">
				<!--- Download file --->
				<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
					<cfexecute name="#attributes.intstruct.theshw#" timeout="600" />
				</cfthread>
			<cfelse>
				<!--- Set Name --->
				<cfset arguments.thestruct.thename = arguments.thestruct.qry_detail.detail.aud_name_org & ".wav">
				<!--- Write --->	
				<cffile action="write" file="#arguments.thestruct.theshw#" output="#thewget# -P #arguments.thestruct.thisfolder# -O #arguments.thestruct.thisfolder#/#arguments.thestruct.thename# #arguments.thestruct.qry_detail.detail.cloud_url_org#" mode="777">
				<!--- Download file --->
				<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
					<cfexecute name="#attributes.intstruct.theshw#" timeout="600" />
				</cfthread>
			</cfif>
			<!--- Wait for the thread above until the file is downloaded fully --->
			<cfthread action="join" name="download#arguments.thestruct.file_id#" />
			<cfthread name="convert#arguments.thestruct.file_id#" />
			<!--- Set the input path --->
			<cfset inputpath = "#arguments.thestruct.thisfolder#/#arguments.thestruct.thename#">
			<!--- Remove wget script --->
			<cffile action="delete" file="#arguments.thestruct.theshw#" />
		<!--- Amazon --->
		<cfelseif application.razuna.storage EQ "amazon" AND arguments.thestruct.link_kind NEQ "lan">
			<!--- Check to see if original file is in WAV format if so take it else take the WAV one --->
			<cfif arguments.thestruct.qry_detail.detail.aud_extension EQ "WAV">
				<!--- Set Name --->
				<cfset arguments.thestruct.thename = arguments.thestruct.qry_detail.detail.aud_name_org>
				<!--- Download file --->
				<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
					<cfinvoke component="amazon" method="Download">
						<cfinvokeargument name="key" value="/#attributes.intstruct.qry_detail.detail.path_to_asset#/#attributes.intstruct.qry_detail.detail.aud_name_org#">
						<cfinvokeargument name="theasset" value="#attributes.intstruct.thisfolder#/#attributes.intstruct.qry_detail.detail.aud_name_org#">
						<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
					</cfinvoke>
				</cfthread>
			<cfelse>
				<!--- Set Name --->
				<cfset arguments.thestruct.thename = arguments.thestruct.qry_detail.detail.aud_name_org & ".wav">
				<!--- Download file --->
				<cfthread name="download#arguments.thestruct.file_id#" intstruct="#arguments.thestruct#">
					<cfinvoke component="amazon" method="Download">
						<cfinvokeargument name="key" value="/#attributes.intstruct.qry_detail.detail.path_to_asset#/#attributes.intstruct.thename#">
						<cfinvokeargument name="theasset" value="#attributes.intstruct.thisfolder#/#attributes.intstruct.thename#">
						<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
					</cfinvoke>
				</cfthread>
			</cfif>
			<!--- Wait for the thread above until the file is downloaded fully --->
			<cfthread action="join" name="download#arguments.thestruct.file_id#" />
			<cfthread name="convert#arguments.thestruct.file_id#" />
			<!--- Set the input path --->
			<cfset inputpath = "#thisfolder#/#arguments.thestruct.thename#">
		<!--- If on LAN --->
		<cfelseif arguments.thestruct.link_kind EQ "lan">
			<cfset inputpath = "#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qry_detail.detail.path_to_asset#/#arguments.thestruct.thenamenoext#.wav">
			<cfthread name="convert#arguments.thestruct.file_id#" />
		</cfif>
		<!--- Wait for the thread above until the file is downloaded fully --->
		<cfthread action="join" name="convert#arguments.thestruct.file_id#" />
		<!--- Ok, file is here so continue --->
		
		<!--- Check the platform and then decide on the ffmpeg tag --->
		<cfif isWindows>
			<cfset arguments.thestruct.theexe = """#arguments.thestruct.thetools.ffmpeg#/ffmpeg.exe""">
			<cfset inputpath = """#inputpath#""">
			<cfset inputpath4copy = inputpath>
		<cfelse>
			<cfset arguments.thestruct.theexe = "#arguments.thestruct.thetools.ffmpeg#/ffmpeg">
			<cfset inputpath4copy = inputpath>
			<cfset inputpath = replace(inputpath," ","\ ","all")>
			<cfset inputpath = replace(inputpath,"&","\&","all")>
			<cfset inputpath = replace(inputpath,"'","\'","all")>
		</cfif>
		<!--- Now, loop over the selected extensions and convert and store audio --->
		<cfloop delimiters="," list="#arguments.thestruct.convert_to#" index="theformat">
			<!--- Param --->
			<cfparam name="arguments.thestruct.convert_bitrate_#theformat#" default="">
			<!--- Create a new ID for the audio --->
			<cftransaction>
				<cfset newid = structnew()>
				<cfset newid.id = replace(createuuid(),"-","","ALL")>
				<cfquery datasource="#application.razuna.datasource#">
				INSERT INTO #session.hostdbprefix#audios
				(aud_id, host_id)
				VALUES( 
				<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#newid.id#">,
				<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#"> 
				)
				</cfquery>
			</cftransaction>
			<!--- Put together the filenames --->
			<cfset newname = listfirst(arguments.thestruct.qry_detail.detail.aud_name, ".")>
			<cfset finalaudioname = "#newname#" & "_" & #newid.id# & "." & #theformat#>
			<!--- If from upload templates we select with and height of image --->
			<cfif arguments.thestruct.upl_template NEQ 0>
				<cfquery datasource="#application.razuna.datasource#" name="qry_b">
				SELECT upl_temp_field, upl_temp_value
				FROM #session.hostdbprefix#upload_templates_val
				WHERE upl_temp_field = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="convert_bitrate_#theformat#">
				AND upl_temp_id_r = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#arguments.thestruct.upl_template#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.thestruct.hostid#">
				</cfquery>
				<!--- Set image width and height --->
				<cfset thebitrate  = qry_b.upl_temp_value>
			<cfelse>
				<cfset thebitrate = Evaluate("arguments.thestruct.convert_bitrate_#theformat#")>
			</cfif>
			<cfif isWindows>
				<cfset thisfinalaudioname = """#thisfolder#/#finalaudioname#""">
				<cfset thisfinalaudioname4copy = thisfinalaudioname>
			<cfelse>
				<cfset thisfinalaudioname = "#thisfolder#/#finalaudioname#">
				<cfset thisfinalaudioname4copy = thisfinalaudioname>
				<cfset thisfinalaudioname = replace(thisfinalaudioname," ","\ ","all")>
				<cfset thisfinalaudioname = replace(thisfinalaudioname,"&","\&","all")>
				<cfset thisfinalaudioname = replace(thisfinalaudioname,"'","\'","all")>
			</cfif>
			<!--- FFMPEG: Set convert parameters for the different types --->
			<cfswitch expression="#theformat#">
				<!--- OGG --->
				<cfcase value="ogg">
					<cfset arguments.thestruct.theargument="-i #inputpath# -acodec libvorbis -aq #thebitrate# -y #thisfinalaudioname#">
				</cfcase>
				<!--- MP3 --->
				<cfcase value="mp3">
					<cfset arguments.thestruct.theargument="-i #inputpath# -ab #thebitrate#k -y #thisfinalaudioname#">
				</cfcase>
				<cfdefaultcase>
					<cfset arguments.thestruct.theargument="-i #inputpath# -y #thisfinalaudioname#">
				</cfdefaultcase>
			</cfswitch>
			<!--- FFMPEG: Convert --->
			<cfset ttexe = "ttexe" & createuuid()>
			<cfset thescript = createuuid()>
			<cfset arguments.thestruct.thesh = "#thisfolder#/#thescript#.sh">
			<!--- On Windows a bat --->
			<cfif isWindows>
				<cfset arguments.thestruct.thesh = "#thisfolder#/#thescript#.bat">
			</cfif>
			<!--- WAV (just copy the file) --->
			<cfif theformat EQ "WAV">
				<cffile action="copy" source="#inputpath4copy#" destination="#thisfinalaudioname4copy#" mode="775">
				<!--- Write files --->
				<cffile action="write" file="#arguments.thestruct.thesh#" output="." mode="777">
				<cfthread name="#ttexe#" />
			<cfelse>
				<!--- Write files --->
				<cffile action="write" file="#arguments.thestruct.thesh#" output="#arguments.thestruct.theexe# #arguments.thestruct.theargument#" mode="777">
				<!--- Convert audio --->
				<cfthread name="#ttexe#" intstruct="#arguments.thestruct#">
					<cfexecute name="#attributes.intstruct.thesh#" timeout="9000" />
				</cfthread>
			</cfif>
			<!--- Wait for the thread above until the file is fully converted --->
			<cfthread action="join" name="#ttexe#" />
			<!--- Delete scripts --->
			<cffile action="delete" file="#arguments.thestruct.thesh#">
			<!--- Check if audio file could be generated by getting the size --->
			<cfinvoke component="global" method="getfilesize" filepath="#thisfolder#/#finalaudioname#" returnvariable="siz">
			<cfif siz EQ 0>
				<cfquery datasource="#application.razuna.datasource#" name="qryuser">
				SELECT user_email
				FROM users
				WHERE user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
				</cfquery>
				<cfinvoke component="email" method="send_email" to="#qryuser.user_email#" subject="Error on converting your audio" themessage="Your Audio could not be converted to the format #ucase(theformat)#. This can happen when the source audio is rendered with codecs that our conversion engine can not read/write.">
			<cfelse>
				<!--- Get size of original --->
				<cfinvoke component="global" method="getfilesize" filepath="#thisfolder#/#finalaudioname#" returnvariable="orgsize">
				<!--- Storage: Local --->
				<cfif application.razuna.storage EQ "local">
					<!--- Now move the files to its own folder --->
					<!--- Create folder first --->
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qry_detail.detail.folder_id_r#/aud/#newid.id#" mode="775">
					<!--- Move Audio --->
					<cffile action="move" source="#thisfolder#/#finalaudioname#" destination="#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thestruct.qry_detail.detail.folder_id_r#/aud/#newid.id#" mode="775">
					<cfthread name="uploadconvert#arguments.thestruct.file_id##theformat#" intstruct="#arguments.thestruct#"></cfthread>
				<!--- Nirvanix --->
				<cfelseif application.razuna.storage EQ "nirvanix">
					<!--- Set variables for thread --->
					<cfset arguments.thestruct.newid = newid.id>
					<cfset arguments.thestruct.finalaudioname = finalaudioname>
					<cfthread name="uploadconvert#arguments.thestruct.file_id##theformat#" intstruct="#arguments.thestruct#">
						<!--- Upload: Audio --->
						<cfinvoke component="nirvanix" method="Upload">
							<cfinvokeargument name="destFolderPath" value="/#attributes.intstruct.qry_detail.detail.folder_id_r#/aud/#attributes.intstruct.newid#">
							<cfinvokeargument name="uploadfile" value="#attributes.intstruct.thisfolder#/#attributes.intstruct.finalaudioname#">
							<cfinvokeargument name="nvxsession" value="#attributes.intstruct.nvxsession#">
						</cfinvoke>
					</cfthread>
					<!--- Wait for this thread to finish --->
					<cfthread action="join" name="uploadconvert#arguments.thestruct.file_id##theformat#" />
					<!--- Get signed URLS --->
					<cfinvoke component="nirvanix" method="signedurl" returnVariable="cloud_url_org" theasset="#arguments.thestruct.qry_detail.detail.folder_id_r#/aud/#arguments.thestruct.newid#/#arguments.thestruct.finalaudioname#" nvxsession="#arguments.thestruct.nvxsession#">
				<!--- Amazon --->
				<cfelseif application.razuna.storage EQ "amazon">
					<!--- Set variables for thread --->
					<cfset arguments.thestruct.newid = newid.id>
					<cfset arguments.thestruct.finalaudioname = finalaudioname>
					<cfthread name="uploadconvert#arguments.thestruct.file_id##theformat#" intstruct="#arguments.thestruct#">
						<!--- Upload: Audio --->
						<cfinvoke component="amazon" method="Upload">
							<cfinvokeargument name="key" value="/#attributes.intstruct.qry_detail.detail.folder_id_r#/aud/#attributes.intstruct.newid#/#attributes.intstruct.finalaudioname#">
							<cfinvokeargument name="theasset" value="#attributes.intstruct.thisfolder#/#attributes.intstruct.finalaudioname#">
							<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
						</cfinvoke>
					</cfthread>
					<!--- Wait for this thread to finish --->
					<cfthread action="join" name="uploadconvert#arguments.thestruct.file_id##theformat#" />
					<!--- Get signed URLS --->
					<cfinvoke component="amazon" method="signedurl" returnVariable="cloud_url_org" key="#arguments.thestruct.qry_detail.detail.folder_id_r#/aud/#arguments.thestruct.newid#/#arguments.thestruct.finalaudioname#" awsbucket="#arguments.thestruct.awsbucket#">
				</cfif>
				<!--- Add to shared options --->
				<cfquery datasource="#application.razuna.datasource#">
				INSERT INTO #session.hostdbprefix#share_options
				(asset_id_r, host_id, group_asset_id, folder_id_r, asset_type, asset_format, asset_dl, asset_order, rec_uuid)
				VALUES(
				<cfqueryparam value="#newid.id#" cfsqltype="CF_SQL_VARCHAR">,
				<cfqueryparam value="#session.hostid#" cfsqltype="cf_sql_numeric">,
				<cfqueryparam value="#arguments.thestruct.file_id#" cfsqltype="CF_SQL_VARCHAR">,
				<cfqueryparam value="#arguments.thestruct.qry_detail.detail.folder_id_r#" cfsqltype="CF_SQL_VARCHAR">,
				<cfqueryparam value="aud" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="#newid.id#" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="1" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="1" cfsqltype="cf_sql_varchar">,
				<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
				)
				</cfquery>
				<!--- Update the audio record with other information --->
				<cfquery datasource="#application.razuna.datasource#">
				UPDATE #session.hostdbprefix#audios
				SET 
				aud_group = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">,
				aud_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#finalaudioname#">,
				aud_owner = <cfqueryparam value="#session.theuserid#" cfsqltype="CF_SQL_VARCHAR">,
				aud_create_date = <cfqueryparam cfsqltype="cf_sql_date" value="#now()#">,
				aud_change_date = <cfqueryparam cfsqltype="cf_sql_date" value="#now()#">,
				aud_create_time = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
				aud_change_time = <cfqueryparam cfsqltype="cf_sql_timestamp" value="#now()#">,
				aud_extension = <cfqueryparam value="#theformat#" cfsqltype="cf_sql_varchar">,
				aud_name_org = <cfqueryparam cfsqltype="cf_sql_varchar" value="#finalaudioname#">,
				folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.qry_detail.detail.folder_id_r#">,
			 	aud_size = <cfqueryparam cfsqltype="cf_sql_numeric" value="#orgsize#">,
			 	path_to_asset = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.thestruct.qry_detail.detail.folder_id_r#/aud/#newid.id#">,
			 	cloud_url_org = <cfqueryparam value="#cloud_url_org.theurl#" cfsqltype="cf_sql_varchar">,
				cloud_url_exp = <cfqueryparam value="#cloud_url_org.newepoch#" cfsqltype="CF_SQL_NUMERIC">,
				is_available = <cfqueryparam value="1" cfsqltype="cf_sql_varchar">
				WHERE aud_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#newid.id#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<!--- Log --->
				<cfset log = #log_assets(theuserid=session.theuserid,logaction='Convert',logdesc='Converted: #arguments.thestruct.qry_detail.detail.aud_name# to #finalaudioname#',logfiletype='aud')#>
				<!--- Call method to send email --->
				<!---
				<cfset arguments.thestruct.emailwhat = "end_converting">
				<cfset arguments.thestruct.convert_to = theformat>
				<cfinvoke component="assets" method="addassetsendmail" thestruct="#arguments.thestruct#">
				--->
				<!--- Flush Cache --->
				<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_audios" />
				<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_share_options" />
			</cfif>
		</cfloop>
		<cfcatch type="any">
			<cfmail to="support@razuna.com" from="server@razuna.com" subject="Error on convert audio" type="html">
				<cfdump var="#cfcatch#">
				<cfdump var="#arguments.thestruct#">
			</cfmail>
		</cfcatch>
	</cftry>
</cffunction>

<!--- GET RELATED AUDIOS --->
<cffunction name="relatedaudios" output="true">
	<cfargument name="thestruct" type="struct">
	<cfquery datasource="#variables.dsn#" name="qry" cachename="aud#session.hostid#relatedaudios#arguments.thestruct.file_id#" cachedomain="#session.theuserid#_audios">
	SELECT aud_id, folder_id_r, aud_name, aud_extension, aud_size, path_to_asset, aud_group
	FROM #session.hostdbprefix#audios
	WHERE aud_group = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.thestruct.file_id#">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	ORDER BY aud_extension
	</cfquery>
	<cfreturn qry>
</cffunction>

<!--- WRITE AUDIO TO SYSTEM --->
<cffunction name="writeaudio" output="true">
	<cfargument name="thestruct" type="struct">
	<cfparam name="arguments.thestruct.zipit" default="T">
	<!--- Create a temp folder --->
	<cfset tempfolder = replace(createuuid(),"-","","ALL")>
	<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#" mode="775">
	<!--- Put the audio id into a variable --->
	<cfset theaudioid = #arguments.thestruct.file_id#>
	<!--- The tool paths --->
	<cfinvoke component="settings" method="get_tools" returnVariable="arguments.thestruct.thetools" />
	<!--- Go grab the platform --->
	<cfinvoke component="assets" method="iswindows" returnvariable="arguments.thestruct.iswindows">
	<!--- Set path for wget --->
	<cfset arguments.thestruct.thewget = "#arguments.thestruct.thetools.wget#/wget">
	<!--- On Windows a .bat --->
	<cfif arguments.thestruct.iswindows>
		<cfset arguments.thestruct.thewget = """#arguments.thestruct.thetools.wget#/wget.exe""">
	</cfif>
	<!--- Start the loop to get the different kinds of audios --->
	<cfloop delimiters="," list="#arguments.thestruct.artofimage#" index="art">
		<!--- Since the video format could be from the related table we need to check this here so if the value is a number it is the id for the video --->
		<cfif isnumeric(art)>
			<!--- Set the video id for this type of format and set the extension --->
			<cfset theaudioid = art>
			<cfquery name="ext" datasource="#variables.dsn#">
			SELECT aud_extension
			FROM #session.hostdbprefix#audios
			WHERE aud_id = <cfqueryparam value="#theaudioid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<cfset art = ext.aud_extension>
		</cfif>
		<!--- Create subfolder for the kind of video --->
		<cfdirectory action="create" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#art#" mode="775">
		<!--- Set the colname to get from oracle to video_preview else to video always --->
		<cfset thecolname = "audio">
		<!--- Query the db --->
		<cfquery name="qry" datasource="#variables.dsn#">
		SELECT a.aud_name, a.aud_extension, a.aud_name_org, a.folder_id_r, a.aud_group, a.link_kind, 
		a.link_path_url, a.path_to_asset, a.cloud_url_org
		FROM #session.hostdbprefix#audios a, #session.hostdbprefix#settings_2 s
		WHERE a.aud_id = <cfqueryparam value="#theaudioid#" cfsqltype="CF_SQL_VARCHAR">
		AND s.set2_id = <cfqueryparam value="#variables.setid#" cfsqltype="cf_sql_numeric">
		AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND s.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- If we have the preview the name is different --->
		<cfset thefinalname = qry.aud_name_org>
		<!--- Put variables into struct for threads --->
		<cfset arguments.thestruct.hostid = session.hostid>
		<cfset arguments.thestruct.qry = qry>
		<cfset arguments.thestruct.theaudioid = theaudioid>
		<cfset arguments.thestruct.tempfolder = tempfolder>
		<cfset arguments.thestruct.art = art>
		<cfset arguments.thestruct.thefinalname = thefinalname>
		<cfset arguments.thestruct.thecolname = thecolname>
		<!--- Local --->
		<cfif application.razuna.storage EQ "local" AND qry.link_kind EQ "">
			<cfthread name="download#art##theaudioid#" intstruct="#arguments.thestruct#">
				<cffile action="copy" source="#attributes.intstruct.assetpath#/#attributes.intstruct.hostid#/#attributes.intstruct.qry.path_to_asset#/#attributes.intstruct.thefinalname#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#" mode="775">
			</cfthread>
		<!--- Nirvanix --->
		<cfelseif application.razuna.storage EQ "nirvanix" AND qry.link_kind EQ "">
			<!--- For wget script --->
			<cfset wgetscript = replace(createuuid(),"-","","all")>
			<cfset arguments.thestruct.thesh = GetTempDirectory() & "/#wgetscript#.sh">
			<!--- On Windows a .bat --->
			<cfif arguments.thestruct.iswindows>
				<cfset arguments.thestruct.thesh = GetTempDirectory() & "/#wgetscript#.bat">
			</cfif>
			<!--- Write --->	
			<cffile action="write" file="#arguments.thestruct.thesh#" output="#arguments.thestruct.thewget# -P #arguments.thestruct.thepath#/outgoing/#arguments.thestruct.tempfolder#/#arguments.thestruct.art# #arguments.thestruct.qry.cloud_url_org#" mode="777">
			<!--- Download file --->
			<cfthread name="download#art##theaudioid#" intstruct="#arguments.thestruct#">
				<cfexecute name="#attributes.intstruct.thesh#" timeout="600" />
			</cfthread>
		<!--- Amazon --->
		<cfelseif application.razuna.storage EQ "amazon" AND qry.link_kind EQ "">
			<!--- Download file --->
			<cfthread name="download#art##theaudioid#" intstruct="#arguments.thestruct#">
				<cfinvoke component="amazon" method="Download">
					<cfinvokeargument name="key" value="/#attributes.intstruct.qry.path_to_asset#/#attributes.intstruct.thefinalname#">
					<cfinvokeargument name="theasset" value="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#">
					<cfinvokeargument name="awsbucket" value="#attributes.intstruct.awsbucket#">
				</cfinvoke>
			</cfthread>
		<!--- If local link --->
		<cfelseif qry.link_kind EQ "lan">
			<!--- Copy file to the outgoing folder --->
			<cfthread name="download#art##theaudioid#" intstruct="#arguments.thestruct#">
				<!--- If Original --->
				<cfif attributes.intstruct.art EQ "audio">
					<cffile action="copy" source="#attributes.intstruct.qry.link_path_url#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#" mode="775">
				<!--- different format --->
				<cfelse>
					<cffile action="copy" source="#attributes.intstruct.assetpath#/#attributes.intstruct.hostid#/#attributes.intstruct.qry.path_to_asset#/#attributes.intstruct.thefinalname#" destination="#attributes.intstruct.thepath#/outgoing/#attributes.intstruct.tempfolder#/#attributes.intstruct.art#/#attributes.intstruct.thefinalname#" mode="775">
				</cfif>
			</cfthread>
		</cfif>
		<!--- Wait for the thread above until the file is downloaded fully --->
		<cfthread action="join" name="download#art##theaudioid#" />
		<!--- For nirvanix remove the wget script --->
		<cfif application.razuna.storage EQ "nirvanix">
			<cffile action="delete" file="#arguments.thestruct.thesh#" />
		</cfif>
		<!--- Set extension --->
		<cfset theext = qry.aud_extension>
		<!--- If the art id not thumb and original we need to get the name from the parent record --->
		<cfif qry.aud_group NEQ "">
			<cfquery name="qry" datasource="#variables.dsn#">
			SELECT aud_name
			FROM #session.hostdbprefix#audios
			WHERE aud_id = <cfqueryparam value="#qry.aud_group#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
		<cfset thenewname = listfirst(qry.aud_name, ".") & "." & theext>
		<!--- Rename the file --->
		<cffile action="move" source="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#art#/#thefinalname#" destination="#arguments.thestruct.thepath#/outgoing/#tempfolder#/#art#/#thenewname#">
	</cfloop>
	<!--- Check that the zip name contains no spaces --->
	<cfset zipname = replacenocase("#arguments.thestruct.zipname#", " ", "_", "All")>
	<cfset zipname = zipname & ".zip">
	<!--- Remove any file with the same name in this directory. Wrap in a cftry so if the file does not exist we don't have a error --->
	<cftry>
		<cffile action="delete" file="#arguments.thestruct.thepath#/outgoing/#zipname#">
		<cfcatch type="any"></cfcatch>
	</cftry>
	<!--- Zip the folder --->
	<cfzip action="create" ZIPFILE="#arguments.thestruct.thepath#/outgoing/#zipname#" source="#arguments.thestruct.thepath#/outgoing/#tempfolder#" recurse="true" timeout="300" />
	<!--- Remove the temp folder --->
	<cfdirectory action="delete" directory="#arguments.thestruct.thepath#/outgoing/#tempfolder#" recurse="yes">
	<!--- Return --->
	<cfreturn #zipname#>
</cffunction>

<!--- Get description and keywords for print --->
<cffunction name="gettext" output="false">
	<cfargument name="qry" type="query">
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="qryintern" cachename="aud#session.hostid#gettext#ValueList(arguments.qry.id)#" cachedomain="#session.theuserid#_audios">
	SELECT aud_id_r tid, aud_description description, aud_keywords keywords
	FROM #session.hostdbprefix#audios_text
	WHERE aud_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.qry.id)#" list="true">)
	AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
	</cfquery>
	<!--- Return --->
	<cfreturn qryintern>
</cffunction>

<!--- GET RECORDS WITH EMTPY VALUES --->
<cffunction name="getempty" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="qry">
	SELECT 
	aud_id id, aud_name, folder_id_r, cloud_url, cloud_url_org, aud_name_org filenameorg, link_kind, link_path_url, 
	path_to_asset, lucene_key
	FROM #session.hostdbprefix#audios
	WHERE (folder_id_r IS NULL OR folder_id_r = '')
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Return --->
	<cfreturn qry>
</cffunction>

</cfcomponent>