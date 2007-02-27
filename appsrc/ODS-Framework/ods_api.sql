
-- ODS API 
-- Contains 2 procedures accessible by SOAP
--  ODS_CREATE_USER                       -- Automatic creation of new user without going trough web registration procedure.
--  in _username varchar,                -- login for user to create
--  in _passwd varchar,                  -- password for created user
--  in _email varchar,                   -- email address for user 
--  in _host varchar := '',              -- desired domain for which user will be created, if not supplied URIQA default host will be taken
--  in _creator_username varchar :='',   -- if registration for domain is prohibited authentication of administrator of the domain is required in order to authorize account create
--  in _creator_passwd varchar :=''      -- password for authorized administrator;
-- 
--  result is INTEGER (created user id) if successful, otherwise varchar - ERROR MESSAGE;
--
--  ODS_CREATE_NEW_APP_INST        -- creates instance of determined type for given user
--  in app_type varchar,          -- VALID WA_TYPE of application to create 
--  in inst_name varchar,         -- desired name for the instance
--  in owner varchar,             -- username of the owner of the instance
--  in model int := 0,            -- refers to Membership model (Open,Closed,Invitation only,Approval based
--  in pub int := 1,              -- refers to Visible to public property
--  in inst_descr varchar := null -- description for the instance
--
-- result is INTEGER (instance id)if successful, otherwise varchar - ERROR MESSAGE
--
-- Access to procedures granted to GDATA_ODS SOAP user using /ods_services endpoint.


DB.DBA.VHOST_REMOVE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/ods_services');

VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/ods_services',ppath=>'/SOAP/',soap_user=>'GDATA_ODS')
;


create procedure
ODS_CREATE_USER(in _username varchar, in _passwd varchar, in _email varchar, in _host varchar := '',in _creator_username varchar :='',in _creator_passwd varchar :='' )
{

   declare dom_reg int;
   declare country, city, lat, lng, xt, xp any;
   declare _err,_port,default_host,default_port,vhost varchar;
   declare _arr any;


   _username := trim(_username);

 
  if(length(_host)=0)
  {
    _host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  }
  
  _arr := split_and_decode (_host, 0, '\0\0:');
  if (length (_arr) > 1)
    {
      default_host := _arr[0];
      default_port := _arr[1];
      vhost := _host;
      _port := ':'||default_port;
    }
  else if (length (_arr) = 1)
    {
      default_host := _host;
      default_port := '80';
      vhost := _host || ':80';
      _port := ':'||default_port;
    }
  else
  {
    _err:='Given domain is incorrect.';
    goto report_err;
    
  }
  
   dom_reg := null;
   whenever not found goto nfd;
     select WD_MODEL into dom_reg from WA_DOMAINS where WD_HOST = vhost and
     WD_LISTEN_HOST = _port and WD_LPATH = '/ods';

   nfd:;

   if (dom_reg is not null)
   {
     if (dom_reg = 0 or
         not exists (select 1 from WA_SETTINGS where WS_REGISTER = 1)
        )
       {

           if(web_user_password_check(_creator_username,_creator_passwd)=0
              or
              not exists(select 1 from SYS_USERS where U_NAME=_creator_username and U_GROUP in (0,3))
             )
           {
              _err := 'Registration is not allowed and user creator\'s authentication is incorrect or creator is not administrator.';
              goto report_err;
           }
       }
   }
   

   declare uid int;
   declare exit handler for sqlstate '*'
   {
     _err := concat (__SQL_STATE,' ',__SQL_MESSAGE);
     rollback work;
     goto report_err;
   };

   -- check if this login already exists
   if (exists(select 1 from DB.DBA.SYS_USERS where U_NAME = _username))
   {
     _err := 'Login name already in use';
     goto report_err;
   }

   -- determine if mail verification is necessary
   declare _mail_verify_on any;
   _mail_verify_on := coalesce((select 1 from WA_SETTINGS where WS_MAIL_VERIFY = 1), 0);

    declare _disabled any;
    -- create user initially disabled
    uid := USER_CREATE (_username, _passwd,
         vector ('E-MAIL', _email,
                 'HOME', '/DAV/home/' || _username || '/',
                 'DAV_ENABLE' , 1,
                 'SQL_ENABLE', 0));
   update SYS_USERS set U_ACCOUNT_DISABLED = _mail_verify_on where U_ID = uid;
   DAV_MAKE_DIR ('/DAV/home/', http_dav_uid (), http_admin_gid (), '110100100R');
   DAV_MAKE_DIR ('/DAV/home/' || _username || '/', uid, http_nogroup_gid (), '110100100R');
 
   WA_USER_SET_INFO(_username, '', '');
   WA_USER_TEXT_SET(uid, _username||' '||_email);
   wa_reg_register (uid, _username);

   {
     declare coords any;
     declare exit handler for sqlstate '*';
     xt := http_client (sprintf ('http://api.hostip.info/?ip=%s', http_client_ip ()));
     xt := xtree_doc (xt);
     country := cast (xpath_eval ('string (//countryName)', xt) as varchar);
     city := cast (xpath_eval ('string (//Hostip/name)', xt) as varchar);
     coords := cast (xpath_eval ('string(//ipLocation//coordinates)', xt) as varchar);
     lat := null;
     lng := null;
     if (country is not null and length (country) > 2)
     {
         country := (select WC_NAME from WA_COUNTRY where upper (WC_NAME) = country);
         if (country is not null)
         {
             declare exit handler for not found;
             select WC_LAT, WC_LNG into lat, lng from WA_COUNTRY where WC_NAME = country;
             WA_USER_EDIT (_username, 'WAUI_HCOUNTRY', country);
         }
     }
     WA_USER_EDIT (_username, 'WAUI_HCITY', city);
     if (coords is not null)
     {
         coords := split_and_decode (coords, 0, '\0\0\,');
         if (length (coords) = 2)
         {
           lat := atof (coords [0]);
           lng := atof (coords [1]);
         }
     }
     if (lat is not null and lng is not null)
      {
         WA_USER_EDIT (_username, 'WAUI_LAT', lat);
         WA_USER_EDIT (_username, 'WAUI_LNG', lng);
         WA_USER_EDIT (_username, 'WAUI_LATLNG_HBDEF', 0);
      }
   }

   insert soft sn_person (sne_name, sne_org_id) values (_username, uid);

    if (_mail_verify_on)
    {
        -- create session
        declare sid any;  
        sid := md5 (concat (datestring (now ()), cast(randomize(999999) as varchar), wa_link(), '/register.vspx'));
        declare _expire integer;
        _expire:=24;
        _expire := coalesce((select top 1 WS_REGISTRATION_EMAIL_EXPIRY from WA_SETTINGS), 1);
        set triggers off;
        insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
               values ('wa', sid, _username, serialize (vector ('vspx_user', _username)), dateadd ('hour', _expire, now()));
        set triggers on;

       -- determine existing default mail server
       declare _smtp_server any;
       if((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1
           or (select length(max(WS_SMTP)) from WA_SETTINGS) = 0)
         _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
       else
         _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
       if (_smtp_server = 0)
       {
         _err := 'Mail is obligatory but verification impossible. Default Mail Server is not defined. ';
         rollback work;
         goto report_err;
       }
       declare msg, _sender_address, body, body1 varchar;
       body := (select coalesce(blob_to_string(RES_CONTENT), 'Not found...') from WS.WS.SYS_DAV_RES
                where  RES_FULL_PATH = '/DAV/VAD/wa/tmpl/WS_REG_TEMPLATE');
       body1 := WA_MAIL_TEMPLATES(body, null, _username, sprintf('%s/conf.vspx?sid=%s&realm=wa', rtrim(WA_LINK(1),'/'),sid ));
       msg := 'Subject: Account registration confirmation\r\nContent-Type: text/plain\r\n';
       msg := msg || body1;
       _sender_address := (select U_E_MAIL from SYS_USERS where U_ID = http_dav_uid ());
       {
         declare exit handler for sqlstate '*'
         {
           declare _use_sys_errors, _sys_error, _error any;
           _sys_error := concat (__SQL_STATE,' ',__SQL_MESSAGE);
           _error := 'Due to a transient problem in the system, your registration could not be
             processed at the moment. The system administrators have been notified. Please
             try again later';
           _use_sys_errors := (select top 1 WS_SHOW_SYSTEM_ERRORS from WA_SETTINGS);
           if(_use_sys_errors)
           {
             _err := _error || ' ' || _sys_error;
           }
           else
           {
             _err := _error;
           }
           rollback work;
           goto report_err;
         };
         
         smtp_send(_smtp_server, _sender_address, _email, msg);
       }
    }
    return uid;  

report_err:;

 return _err;

};

grant execute on ODS_CREATE_USER to GDATA_ODS;



create procedure
ODS_CREATE_NEW_APP_INST (in app_type varchar, in inst_name varchar, in owner varchar, in model int := 0, in pub int := 1, in inst_descr varchar := null)
{
  declare inst web_app;
  declare ty, h, id any;
  declare _err varchar;
  declare _u_id,_wai_id integer;

  _err:='';

  -- check for correct instance name
  
  if ( length(coalesce(inst_name, ''))<1 or length(coalesce(inst_name, ''))>55)
  {
       _err:='Instance name should not be empty and not longer than 55 characters;';
       goto report_err;
  }
   

  --check for existing instance with the same name
   if (exists(select 1 from WA_INSTANCE where WAI_NAME = inst_name))
   {
       _err:='Instance with name - '||inst_name||' already exists;';
       goto report_err;
   } 
   
  --check that user is correct/exists
   {
    declare exit handler for not found
           {
            _err:='User - '||owner||' does not exists;';
            goto report_err;
           };
    
    select U_ID into _u_id from SYS_USERS where U_NAME=owner;
   }


  --check for correct/installed application_type
  {        
   declare exit handler for not found
          {
           _err:='Application type - '||app_type||' does not exists; ';
           goto report_err;
          };
   select WAT_TYPE into ty from WA_TYPES where WAT_NAME = app_type;
  }

  inst := __udt_instantiate_class (fix_identifier_case (ty), 0);
  inst.wa_name := inst_name;
  inst.wa_member_model := model;


  h := udt_implements_method (inst, 'wa_new_inst');

 
  if (h<>0)
  {
    {
     declare exit handler for sqlstate '*'
     {
       _err:='Cannot create "'|| inst_name ||'" of type '||app_type ||' for '||owner||'. SQL_ERR: '|| concat (__SQL_STATE, ' ', __SQL_MESSAGE) ||';';
       goto report_err;
     };

     id := call (h) (inst, owner);
    }

   
    if(id<>0){
      update WA_INSTANCE
             set WAI_MEMBER_MODEL = model,
                 WAI_IS_PUBLIC = pub,
                 WAI_MEMBERS_VISIBLE = 1,
                 WAI_NAME = inst_name,
                 WAI_DESCRIPTION = coalesce(inst_descr,inst_name || ' Description')
           where WAI_ID = id;
    }else
    {
       _err:='Cannot update properties for '|| inst_name ||' of type '|| app_type ||' for '||owner||';';
       goto report_err;
    }  
  }else
  {
    _err:='Application type '|| app_type ||' do not support wa_new_inst() method;';
    goto report_err;
  }
  
 return id;


report_err:;
 
 return _err;
};

grant execute on ODS_CREATE_NEW_APP_INST to GDATA_ODS;
