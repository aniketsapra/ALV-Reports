*&---------------------------------------------------------------------*
*& Report  : Z_CALIBRATION_REPORT
*& Title   : Daily/monthly calibration tracking report.
*& Purpose : Report for consolidated Daily/monthly calibration tracking.
*&---------------------------------------------------------------------*
*& *  Change Log:
*     - <YYYY-MM-DD>  <Init/Enh/Fix>                      <Description>                                                                     <By>
*     - 2026-04-30    Init
*     - 2026-05-08    TECO Field                          New Field Added VIAUFKS - IDAT2                                                   Aniket Sapra
*                     Frequecy Field Calculation          Divide frequency by 86400 to get Days. if MMPT~ZEIEH = ‘MON’, divide it by 30.    Aniket Sapra
*                     Equipment Selection change          INNER JOIN MPOS ON MPOS~WARPL = MPLA~WARPL                                        Aniket Sapra
*                     Equipment Desc Selection change     Join EQKT on EQKT~EQUNR = MPOS~EQUNR
*&---------------------------------------------------------------------*

REPORT z_calibration_report.

TABLES : mpla, mhis, eqkt, mmpt, viaufks, mpos.

INCLUDE z_calibration_report_top.
INCLUDE z_calibration_report_sel.
INCLUDE z_calibration_report_fetch.

START-OF-SELECTION.
  PERFORM get_data.
  PERFORM generate_fcat.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
*& Include          Z_CALIBRATION_REPORT_TOP
*&---------------------------------------------------------------------*

TYPES : BEGIN OF ty_final,
          warpl	TYPE warpl,
          frqcy TYPE char50, "Frequency = (mmpt-zykl1 + mmpt-zeieh)
          abnum TYPE abnum,
          equnr TYPE equnr,
          eqktx TYPE ktx01,
          tplnr TYPE tplnr,
          stadt TYPE stadt,
          nplda TYPE nplda,
          abrud TYPE abrud,
          aufnr TYPE aufnr,
          idat2 type viaufks-idat2,
        END OF ty_final.

DATA : it_final TYPE TABLE OF ty_final,
       wa_final TYPE ty_final.

DATA: it_fieldcat TYPE lvc_t_fcat,
      wa_fieldcat TYPE lvc_s_fcat,
      wa_layout   TYPE lvc_s_layo.

data : fr_days TYPE p DECIMALS 2.

*&---------------------------------------------------------------------*
*& Include          Z_CALIBRATION_REPORT_SEL
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1.

  SELECT-OPTIONS : s_warpl FOR mpla-warpl,
                   s_aufnr FOR viaufks-aufnr,
                   s_werks FOR viaufks-werks OBLIGATORY,
                   s_equnr FOR mpos-equnr,
                   s_ersdt FOR mpla-ersdt,
                   s_ernam FOR mpla-ernam.


SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& Include          Z_CALIBRATION_REPORT_FETCH
*&---------------------------------------------------------------------*
*

FORM get_data.

  CLEAR: it_final.

  SELECT mpla~warpl,
         mmpt~zykl1,
         mmpt~zeieh,
         mhis~abnum,
         mhis~stadt,
         mhis~nplda,
         mhis~abrud,
         mpos~equnr
    FROM mpla
    LEFT JOIN mmpt
      ON mmpt~warpl = mpla~warpl
    LEFT JOIN mhis
      ON mhis~warpl = mpla~warpl
    INNER JOIN mpos
      ON mpos~warpl = mpla~warpl
    INTO TABLE @DATA(it_main)
    WHERE mpla~mptyp = 'CL'
      AND mpla~warpl IN @s_warpl
      AND mpla~ersdt IN @s_ersdt
      AND mpla~ernam IN @s_ernam
      AND mpos~equnr IN @s_equnr.


  IF it_main IS INITIAL.
    RETURN.
  ENDIF.

  SELECT warpl,
         abnum,
         tplnr,
         aufnr,
         idat2,
         werks,
         equnr
    FROM viaufks
    INTO TABLE @DATA(it_viaufks)
    FOR ALL ENTRIES IN @it_main
    WHERE warpl = @it_main-warpl
      AND abnum = @it_main-abnum
*      AND aufnr IN @s_aufnr
      AND werks IN @s_werks
      AND equnr IN @s_equnr.

  SORT it_viaufks BY warpl abnum.

  SELECT equnr,
         eqktx
    FROM eqkt
    INTO TABLE @DATA(it_eqkt)
    FOR ALL ENTRIES IN @it_main
    WHERE equnr = @it_main-equnr
      AND spras = @sy-langu.

  SORT it_eqkt BY equnr.

  LOOP AT it_main INTO DATA(wa_main).

    CLEAR wa_final.

    wa_final-warpl = wa_main-warpl.
    SHIFT wa_final-warpl LEFT DELETING LEADING '0'.
    wa_final-abnum = wa_main-abnum.
    wa_final-stadt = wa_main-stadt.
    wa_final-nplda = wa_main-nplda.
    wa_final-abrud = wa_main-abrud.
    wa_final-equnr = wa_main-equnr.
    SHIFT wa_final-equnr LEFT DELETING LEADING '0'.

** Frequency
** MMPT-ZYKL1 is stored in seconds.
** Seconds / 86400 = Days
** If ZEIEH = MON, divide days by 30.

    fr_days = wa_main-zykl1 / 86400.

    IF wa_main-zeieh = 'MON'.
      fr_days = fr_days / 30.
    ENDIF.

    wa_final-frqcy = |{ fr_days } { wa_main-zeieh }|.


    DATA(lv_viaufks_found) = abap_false.

    LOOP AT it_viaufks INTO DATA(wa_viaufks)
         WHERE warpl = wa_main-warpl
           AND abnum = wa_main-abnum.


      IF s_aufnr[] IS NOT INITIAL
         AND wa_viaufks-aufnr NOT IN s_aufnr.

        CONTINUE.

      ENDIF.


      lv_viaufks_found = abap_true.
      wa_final-tplnr = wa_viaufks-tplnr.
      wa_final-aufnr = wa_viaufks-aufnr.
      SHIFT wa_final-aufnr LEFT DELETING LEADING '0'.
      wa_final-idat2 = wa_viaufks-idat2.
      EXIT.

    ENDLOOP.

    IF s_aufnr[] IS NOT INITIAL
       AND lv_viaufks_found = abap_false.
      CONTINUE.
    ENDIF.

    READ TABLE it_eqkt INTO DATA(wa_eqkt)
         WITH KEY equnr = wa_main-equnr
         BINARY SEARCH.
    IF sy-subrc = 0.
      wa_final-eqktx = wa_eqkt-eqktx.
    ENDIF.

    APPEND wa_final TO it_final.

  ENDLOOP.


ENDFORM.

FORM generate_fcat.

  DEFINE add_fcat.
    CLEAR wa_fieldcat.
    wa_fieldcat-fieldname = &1.
    wa_fieldcat-coltext   = &2.
    wa_fieldcat-col_opt = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
  END-OF-DEFINITION.

  add_fcat 'WARPL'        'Calibration Plan'.
  add_fcat 'FRQCY'        'Frequency'.
  add_fcat 'ABNUM'        'Call Number'.
  add_fcat 'EQUNR'        'Equipment'.
  add_fcat 'EQKTX'        'Equipment Description'.
  add_fcat 'TPLNR'        'Functional Location'.
  add_fcat 'STADT'        'Schedule Date'.
  add_fcat 'NPLDA'        'Due Date'.
  add_fcat 'ABRUD'        'Last Call on'.
  add_fcat 'AUFNR'        'Order'.
  add_fcat 'IDAT2'        'TECO Date'.
  wa_layout-zebra = 'X'.
  wa_layout-col_opt = 'X'.

ENDFORM.

FORM display_alv.

  CALL FUNCTION 'REUSE_ALV_GRID_DISPLAY_LVC'
    EXPORTING
      i_callback_program = sy-repid
      is_layout_lvc      = wa_layout
      it_fieldcat_lvc    = it_fieldcat
    TABLES
      t_outtab           = it_final
    EXCEPTIONS
      program_error      = 1
      OTHERS             = 2.
  IF sy-subrc <> 0.
    MESSAGE 'Error Displaying ALV output' TYPE 'E'.
  ENDIF.


ENDFORM.
