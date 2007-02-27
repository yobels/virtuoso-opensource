--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--


use sioc;

create procedure nntp_role_iri (in name varchar)
{
  return sprintf ('http://%s%s/discussion/%U#reader', get_cname(), get_base_path (), name);
};


create procedure fill_ods_nntp_sioc (in graph_iri varchar, in site_iri varchar, in _wai_name varchar := null)
    {
  declare iri, firi, title, arr, link, riri, maker, maker_iri varchar;
{
    declare deadl, cnt any;
    declare _grp, _msg any;

    _grp := -1;
    _msg := '';
    deadl := 5;
    cnt := 0;
    declare exit handler for sqlstate '40001' {
      if (deadl <= 0)
	resignal;
      rollback work;
      deadl := deadl - 1;
      goto l0;
};
    l0:

  for select NG_GROUP, NG_NAME, NG_DESC, NG_TYPE from DB.DBA.NEWS_GROUPS where NG_GROUP > _grp do
    {
      firi := forum_iri ('nntpf', NG_NAME);
      sioc_forum (graph_iri, site_iri, firi, NG_NAME, 'nntpf', NG_DESC);
      riri := nntp_role_iri (NG_NAME);
      DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
      DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('scope_of'), riri);
      for select NM_KEY_ID from DB.DBA.NEWS_MULTI_MSG, DB.DBA.NEWS_MSG
	where NM_GROUP = NG_GROUP and NM_KEY_ID > _msg do
	  {
	    declare par_iri, par_id, links_to any;
            declare _NM_ID, _NM_REC_DATE, _NM_HEAD, _NM_BODY any;

	    whenever not found goto nxt;
	    select NM_ID, NM_REC_DATE, NM_HEAD, NM_BODY
		into _NM_ID, _NM_REC_DATE, _NM_HEAD, _NM_BODY
		from DB.DBA.NEWS_MSG
		where NM_ID = NM_KEY_ID and NM_TYPE = NG_TYPE;

	    iri := nntp_post_iri (NG_NAME, _NM_ID);
	    arr := deserialize (_NM_HEAD);
	    title := get_keyword ('Subject', arr[0]);
	    maker := get_keyword ('From', arr[0]);
	    maker := DB.DBA.nntpf_get_sender (maker);
	    maker_iri := null;
	    if (maker is not null)
	      {
	        maker_iri := 'mailto:'||maker;
		foaf_maker (graph_iri, maker_iri, null, maker);
	      }
	    DB.DBA.nntpf_decode_subj (title);
	    link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (_NM_ID));
	    links_to := DB.DBA.nntpf_get_links (_NM_BODY);
--	    dbg_obj_print (iri, links_to);
	    ods_sioc_post (graph_iri, iri, firi, null, title, _NM_REC_DATE, _NM_REC_DATE, link, _NM_BODY, null, links_to, maker_iri);

	    par_id := (select FTHR_REFER from DB.DBA.NNFE_THR where FTHR_MESS_ID = _NM_ID and FTHR_GROUP = NG_GROUP);
	    if (par_id is not null)
	      {
		par_iri := nntp_post_iri (NG_NAME, par_id);
		DB.DBA.RDF_QUAD_URI (graph_iri, par_iri, sioc_iri ('has_reply'), iri);
		DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), par_iri);
	      }
	    nxt:
	    cnt := cnt + 1;
	    if (mod (cnt, 500) = 0)
	      {
		commit work;
		_msg := NM_KEY_ID;
	      }
	  }
       for select U_NAME from DB.DBA.SYS_USERS where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0
	 do
	   {
	     declare user_iri varchar;
             user_iri := user_obj_iri (U_NAME);
	     DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('function_of'), user_iri);
	     DB.DBA.RDF_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), riri);
	   }
	 commit work;
	 _grp := NG_GROUP;
    }
  commit work;
    }
};

create procedure ods_nntp_sioc_init ()
{
  declare sioc_version any;

  sioc_version := registry_get ('__ods_sioc_version');

  if (registry_get ('__ods_sioc_init') <> sioc_version)
    return;

  if (registry_get ('__ods_nntp_sioc_init') = sioc_version)
    return;

  fill_ods_nntp_sioc (get_graph (), get_graph ());
  registry_set ('__ods_nntp_sioc_init', sioc_version);
  return;

};

--db.dba.wa_exec_no_error('ods_nntp_sioc_init ()');


create trigger NEWS_GROUPS_SIOC_I after insert on DB.DBA.NEWS_GROUPS referencing new as N
{
  declare firi, graph_iri, site_iri, riri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  site_iri  := get_graph ();
  graph_iri := get_graph ();
  firi := forum_iri ('nntpf', N.NG_NAME);
  sioc_forum (graph_iri, site_iri, firi, N.NG_NAME, 'nntpf', N.NG_DESC);
  riri := nntp_role_iri (N.NG_NAME);
  DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('has_scope'), firi);
  DB.DBA.RDF_QUAD_URI (graph_iri, firi, sioc_iri ('scope_of'), riri);
  for select U_NAME from DB.DBA.SYS_USERS where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0
    do
      {
	declare user_iri varchar;
	user_iri := user_obj_iri (U_NAME);
	DB.DBA.RDF_QUAD_URI (graph_iri, riri, sioc_iri ('function_of'), user_iri);
	DB.DBA.RDF_QUAD_URI (graph_iri, user_iri, sioc_iri ('has_function'), riri);
      }
  return;
};

create trigger NEWS_GROUPS_SIOC_D after delete on DB.DBA.NEWS_GROUPS referencing old as O
{
  declare iri, graph_iri varchar;
  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();
  iri := forum_iri ('nntpf', O.NG_NAME);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

create trigger NNFE_THR_REPLY_I after insert on DB.DBA.NNFE_THR referencing new as N
{
  declare iri, graph_iri, par_iri varchar;
  declare g_name any;

  if (N.FTHR_TOP = 1)
    return;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;
  select NG_NAME into g_name from DB.DBA.NEWS_GROUPS where NG_GROUP = N.FTHR_GROUP;

  iri := nntp_post_iri (g_name, N.FTHR_MESS_ID);
  par_iri := nntp_post_iri (g_name, N.FTHR_REFER);
  DB.DBA.RDF_QUAD_URI (graph_iri, par_iri, sioc_iri ('has_reply'), iri);
  DB.DBA.RDF_QUAD_URI (graph_iri, iri, sioc_iri ('reply_of'), par_iri);
};

create trigger NEWS_MULTI_MSG_SIOC_I after insert on DB.DBA.NEWS_MULTI_MSG referencing new as N
{
  declare iri, graph_iri, firi, arr, title, link, maker, maker_iri varchar;
  declare g_name, g_type, m_id, m_date, m_head, m_body, links_to any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;

  select NG_NAME, NG_TYPE into g_name, g_type from DB.DBA.NEWS_GROUPS where NG_GROUP = N.NM_GROUP;
  select NM_ID, NM_REC_DATE, NM_HEAD, NM_BODY into m_id, m_date, m_head, m_body
      from DB.DBA.NEWS_MSG where NM_ID = N.NM_KEY_ID and NM_TYPE = g_type;

  firi := forum_iri ('nntpf', g_name);
  iri := nntp_post_iri (g_name, m_id);
  arr := deserialize (m_head);
  title := get_keyword ('Subject', arr[0]);
  DB.DBA.nntpf_decode_subj (title);
  maker := get_keyword ('From', arr[0]);
  maker := DB.DBA.nntpf_get_sender (maker);
  maker_iri := null;
  if (maker is not null)
    {
      maker_iri := 'mailto:'||maker;
      foaf_maker (graph_iri, maker_iri, null, maker);
    }
  link := sprintf ('http://%s/nntpf/nntpf_disp_article.vspx?id=%U', DB.DBA.WA_CNAME (), encode_base64 (m_id));
  links_to := DB.DBA.nntpf_get_links (m_body);
  ods_sioc_post (graph_iri, iri, firi, null, title, m_date, m_date, link, m_body, null, links_to, maker_iri);
  return;
};

create trigger NEWS_MULTI_MSG_SIOC_D after delete on DB.DBA.NEWS_MULTI_MSG referencing old as O
{
  declare iri, graph_iri, firi varchar;
  declare g_name, g_type any;

  declare exit handler for sqlstate '*' {
    sioc_log_message (__SQL_MESSAGE);
    return;
  };
  graph_iri := get_graph ();

  declare exit handler for not found;
  select NG_NAME, NG_TYPE into g_name, g_type from DB.DBA.NEWS_GROUPS where NG_GROUP = O.NM_GROUP;
  iri := nntp_post_iri (g_name, O.NM_KEY_ID);
  delete_quad_s_or_o (graph_iri, iri, iri);
  return;
};

use DB;

use DB;
-- NNTPF

wa_exec_no_error ('drop view ODS_NNTP_GROUPS');
wa_exec_no_error ('drop view ODS_NNTP_POSTS');
wa_exec_no_error ('drop view ODS_NNTP_USERS');
wa_exec_no_error ('drop view ODS_NNTP_LINKS');

create view ODS_NNTP_GROUPS as select NG_NAME, NG_DESC, '' as DUMMY from DB.DBA.NEWS_GROUPS;

create view ODS_NNTP_POSTS as select
	NG_GROUP,
	NG_NAME,
	NM_ID,
	sioc..sioc_date (NM_REC_DATE) as REC_DATE,
	NM_HEAD,
	NM_BODY,
	FTHR_SUBJ,
	concat ('mailto:', FTHR_FROM) as MAKER,
	FTHR_REFER
	from
	DB.DBA.NEWS_MSG join DB.DBA.NEWS_MULTI_MSG on (NM_ID = NM_KEY_ID)
    	join DB.DBA.NEWS_GROUPS on (NM_GROUP = NG_GROUP and NM_TYPE = NG_TYPE)
    	left outer join DB.DBA.NNFE_THR on (FTHR_MESS_ID = NM_ID and FTHR_GROUP = NG_GROUP);

create view ODS_NNTP_USERS as select NG_NAME, U_NAME from DB.DBA.NEWS_GROUPS, DB.DBA.SYS_USERS
	where U_DAV_ENABLE = 1 and U_NAME <> 'nobody' and U_NAME <> 'nogroup' and U_IS_ROLE = 0;

create view ODS_NNTP_LINKS as select NML_MSG_ID, NML_URL, NG_NAME
	from
	NNTPF_MSG_LINKS
	join DB.DBA.NEWS_MULTI_MSG on (NML_MSG_ID = NM_KEY_ID)
	join DB.DBA.NEWS_GROUPS on (NM_GROUP = NG_GROUP);

create procedure sioc.DBA.rdf_nntpf_view_str ()
{
  return
      '
      # NNTP forum
      # SIOC
      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_GROUPS.NG_NAME) a sioc:Forum ;
      sioc:id NG_NAME ;
      sioc:type "discussion" ;
      sioc:description NG_DESC ;
      sioc:has_host sioc:default_site (DUMMY) .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.NM_ID) a sioc:Post ;
      sioc:content NM_BODY ;
      dc:title FTHR_SUBJ ;
      dct:created  REC_DATE ;
      dct:modified REC_DATE ;
      foaf:maker sioc:iri (MAKER) ;
      sioc:reply_of sioc:nntp_post_iri (NG_NAME, FTHR_REFER) ;
      sioc:has_container sioc:nntp_forum_iri (NG_NAME) .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.FTHR_REFER)
      sioc:has_reply
      sioc:nntp_post_iri (NG_NAME, NM_ID) .

      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME)
      sioc:container_of
      sioc:nntp_post_iri (NG_NAME, NM_ID) .

      #OLD version sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_USERS.NG_NAME)
      #sioc:has_member
      #sioc:user_iri (U_NAME) .

      sioc:nntp_role_iri (DB.DBA.NEWS_GROUPS.NG_NAME)
      sioc:has_scope
      sioc:nntp_forum_iri (NG_NAME) .

      sioc:nntp_forum_iri (DB.DBA.NEWS_GROUPS.NG_NAME)
      sioc:scope_of
      sioc:nntp_role_iri (NG_NAME) .

      sioc:user_iri (DB.DBA.ODS_NNTP_USERS.U_NAME)
      sioc:has_function
      sioc:nntp_role_iri (NG_NAME) .

      sioc:nntp_role_iri (DB.DBA.ODS_NNTP_USERS.NG_NAME)
      sioc:function_of
      sioc:user_iri (U_NAME) .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_LINKS.NG_NAME, DB.DBA.ODS_NNTP_LINKS.NML_MSG_ID)
      sioc:links_to
      sioc:iri (NML_URL) .

      # AtomOWL
      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_GROUPS.NG_NAME) a atom:Feed .

      sioc:nntp_post_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.NM_ID) a atom:Entry ;
      atom:title FTHR_SUBJ ;
      atom:source sioc:nntp_forum_iri (NG_NAME) ;
      atom:author sioc:iri (MAKER) ;
      atom:published REC_DATE ;
      atom:updated REC_DATE ;
      atom:content sioc:nntp_post_text_iri (NG_NAME, NM_ID) .

      sioc:nntp_post_text_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME, DB.DBA.ODS_NNTP_POSTS.NM_ID) a atom:Content ;
      atom:type "text/plain"  option (EXCLUSIVE) ;
      atom:lang "en-US"  option (EXCLUSIVE) ;
      atom:body NM_BODY .

      sioc:nntp_forum_iri (DB.DBA.ODS_NNTP_POSTS.NG_NAME)
      atom:contains
      sioc:nntp_post_iri (NG_NAME, NM_ID) .

      '
      ;
};

-- END NNTPF

grant select on ODS_NNTP_GROUPS to "SPARQL";
grant select on ODS_NNTP_POSTS to "SPARQL";
grant select on ODS_NNTP_USERS to "SPARQL";
grant select on ODS_NNTP_LINKS to "SPARQL";


ODS_RDF_VIEW_INIT ();
