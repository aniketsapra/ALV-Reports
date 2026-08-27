*&---------------------------------------------------------------------*
*& Report ZPP_RMPM_SHORTAGE_COL
*&---------------------------------------------------------------------*
*& Title   : RM_PM_Shortage Collective Output Report
*& Purpose : Customised Report System will provide a custom transaction code to generate the RM PM Shortage.
*            User will enter selection criteria
*             •	Collective Output
*            and system  will fetch the Report.

REPORT ZPP_RMPM_SHORTAGE_COL.

TABLES : resb, mard, makt, ekpo, afko, ekko, afpo, mseg.

INCLUDE zpp_rmpm_shortage_col_top.
INCLUDE zpp_rmpm_shortage_col_sel.
INCLUDE zpp_rmpm_shortage_col_fetch.
INCLUDE zpp_rmpm_shortage_col_fc.

START-OF-SELECTION.
  PERFORM get_data.
  PERFORM get_fieldcat.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
*& Include          ZPP_RMPM_SHORTAGE_RPT_TOP
*&---------------------------------------------------------------------*

TYPES : BEGIN OF ty_final,
          werks       TYPE werks_d,
          baugr       TYPE baugr,
          aufnr       TYPE aufnr,
          gltrp       TYPE co_gltrp,
          matnr       TYPE matnr,
          maktx       TYPE maktx,
          bdter       TYPE bdter,
          bdmng       TYPE bdmng,
          labst       TYPE labst,
          po_qty      TYPE menge_d,
          stock       TYPE char10,       " stock allocation
          short       TYPE bdmng, "*********************************

END OF ty_final.

DATA : it_final TYPE TABLE OF ty_final,
       wa_final TYPE ty_final.

DATA: it_fieldcat TYPE lvc_t_fcat,
      wa_fieldcat TYPE lvc_s_fcat,
      wa_layout   TYPE lvc_s_layo.

"new

TYPES: BEGIN OF ty_main_sum,
         aufnr TYPE aufnr,
         gstrp TYPE co_gstrp,
         gltrp TYPE co_gltrp,
         baugr TYPE baugr,
         werks TYPE werks_d,
         matnr TYPE matnr,
         bdter TYPE bdter,
         bdmng TYPE bdmng,
       END OF ty_main_sum.

DATA: it_main_sum TYPE SORTED TABLE OF ty_main_sum
                  WITH UNIQUE KEY werks matnr bdter.

*&---------------------------------------------------------------------*
*& Include          ZPP_RMPM_SHORTAGE_COL_SEL
*&---------------------------------------------------------------------*

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE text-001.

  SELECT-OPTIONS : s_werks for resb-werks,
                   s_schdt for afko-gstrp.

SELECTION-SCREEN END OF BLOCK b1.

*&---------------------------------------------------------------------*
*& Include          ZPP_RMPM_SHORTAGE_COL_FETCH
*&---------------------------------------------------------------------*

FORM get_data.

  SELECT afko~aufnr,
         afko~gstrp,
         afko~gltrp,
         resb~baugr,
         resb~werks,
         resb~matnr,
         resb~bdter,
         resb~bdmng
    FROM afko
    INNER JOIN resb ON afko~aufnr = resb~aufnr
    INTO TABLE @DATA(it_main)
    WHERE ( afko~gstrp IN @s_schdt OR afko~gltrp IN @s_schdt )
    AND resb~werks IN @s_werks.

  IF sy-subrc <> 0.
    MESSAGE 'No records found for selection criteria' TYPE 'S' DISPLAY LIKE 'E'.
*     LEAVE TO SCREEN 1.
  ENDIF.

*  SORT it_main BY werks matnr bdter.
  SORT it_main BY werks matnr bdter.

  CLEAR it_main_sum.

  LOOP AT it_main INTO DATA(wa_main1).

    READ TABLE it_main_sum ASSIGNING FIELD-SYMBOL(<fs_sum>)
      WITH TABLE KEY werks = wa_main1-werks
                     matnr = wa_main1-matnr
                     bdter = wa_main1-bdter.

    IF sy-subrc = 0.

      <fs_sum>-bdmng = <fs_sum>-bdmng + wa_main1-bdmng.

    ELSE.

      INSERT VALUE #(
        aufnr = wa_main1-aufnr
        gstrp = wa_main1-gstrp
        gltrp = wa_main1-gltrp
        baugr = wa_main1-baugr
        werks = wa_main1-werks
        matnr = wa_main1-matnr
        bdter = wa_main1-bdter
        bdmng = wa_main1-bdmng
      ) INTO TABLE it_main_sum.

    ENDIF.

  ENDLOOP.


  IF it_main IS NOT INITIAL.


    SELECT matnr,
          maktx
     FROM makt
     INTO TABLE @DATA(it_makt)
     FOR ALL ENTRIES IN @it_main
     WHERE matnr = @it_main-matnr
       AND spras = @sy-langu.

    SORT it_makt BY matnr.


    SELECT matnr,
           werks,
           labst
      FROM mard
      INTO TABLE @DATA(it_mard)
        FOR ALL ENTRIES IN @it_main
      WHERE werks IN @s_werks
        AND matnr = @it_main-matnr.

    SELECT ekko~bedat,
           ekko~ebeln,
           ekpo~ebelp,
           ekpo~matnr,
           ekpo~menge,
           ekpo~werks
      FROM ekko
      INNER JOIN ekpo ON ekko~ebeln = ekpo~ebeln
      INTO TABLE @DATA(it_ekpo)
      FOR ALL ENTRIES IN @it_main WHERE ekko~bedat >= @it_main-gstrp
                                    AND ekko~bedat <= @it_main-gltrp
                                    AND ekpo~loekz = ''
*                                    AND ekpo~elikz = '' "'X'
                                    AND ekpo~werks = @it_main-werks
                                    AND ekpo~matnr = @it_main-matnr.
    SORT it_ekpo BY ebeln ebelp.

    SELECT ebeln, ebelp, menge, bwart
      FROM mseg
      INTO TABLE @DATA(it_mseg)
      FOR ALL ENTRIES IN @it_ekpo WHERE ebeln = @it_ekpo-ebeln
                                    AND ebelp = @it_ekpo-ebelp
                                    AND bwart IN ('101', '102').
    SORT it_mseg BY ebeln ebelp.
    SORT it_mard BY matnr werks.
  ENDIF.


  LOOP AT it_main_sum INTO DATA(wa_main).
    CLEAR wa_final.

    DATA: lv_gr_qty   TYPE menge_d,
          lv_rev_qty  TYPE menge_d,
          lv_open_qty TYPE menge_d.

    wa_final-aufnr = wa_main-aufnr.
    SHIFT wa_final-aufnr LEFT DELETING LEADING '0'.

    wa_final-gltrp = wa_main-gltrp.
    wa_final-baugr = wa_main-baugr.
    SHIFT wa_final-baugr LEFT DELETING LEADING '0'.

    wa_final-werks = wa_main-werks.

    wa_final-matnr = wa_main-matnr.
    SHIFT wa_final-matnr LEFT DELETING LEADING '0'.

    wa_final-bdter = wa_main-bdter.
    wa_final-bdmng = wa_main-bdmng.

    READ TABLE it_makt INTO DATA(wa_makt)
      WITH KEY matnr = wa_main-matnr
       BINARY SEARCH.
    IF sy-subrc = 0.
      wa_final-maktx = wa_makt-maktx.
*      wa_final-labst = wa_m2-labst.
    ENDIF.


    CLEAR wa_final-labst.

    LOOP AT it_mard INTO DATA(wa_mard)
      WHERE matnr = wa_main-matnr
        AND werks = wa_main-werks.

      wa_final-labst =
        wa_final-labst + wa_mard-labst.

    ENDLOOP.


*    IF wa_m2-labst IS NOT INITIAL OR wa_main-bdmng IS NOT INITIAL.
    wa_final-short = wa_final-labst - wa_main-bdmng.
*    ENDIF.

    LOOP AT it_ekpo INTO DATA(wa_ekpo) WHERE matnr = wa_main-matnr
                                       AND werks = wa_main-werks.

      CLEAR : lv_gr_qty,
              lv_rev_qty,
              lv_open_qty.

      LOOP AT it_mseg INTO DATA(wa_mseg)
        WHERE ebeln = wa_ekpo-ebeln
          AND ebelp = wa_ekpo-ebelp.

        CASE wa_mseg-bwart.

          WHEN '101'.
            lv_gr_qty = lv_gr_qty + wa_mseg-menge.

          WHEN '102'.
            lv_rev_qty = lv_rev_qty + wa_mseg-menge.

        ENDCASE.

      ENDLOOP.

* effective received qty
*    wa_final-po_qty = wa_ek-menge - ( lv_gr_qty - lv_rev_qty ).

      lv_open_qty =
        wa_ekpo-menge -
        ( lv_gr_qty - lv_rev_qty ).

      wa_final-po_qty =
        wa_final-po_qty + lv_open_qty.

    ENDLOOP.

    APPEND wa_final TO it_final.


  ENDLOOP.

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

*&---------------------------------------------------------------------*
*& Include          ZPP_RMPM_SHORTAGE_COL_FC
*&---------------------------------------------------------------------*

FORM get_fieldcat.

  DEFINE add_fcat.
    CLEAR wa_fieldcat.
    wa_fieldcat-fieldname = &1.
    wa_fieldcat-coltext   = &2.
    wa_fieldcat-col_opt = 'X'.
    APPEND wa_fieldcat TO it_fieldcat.
  END-OF-DEFINITION.

  wa_layout-zebra = 'X'.
  wa_layout-col_opt = 'X'.

    add_fcat 'WERKS'        'Plant'.
    add_fcat 'MATNR'        'Component'.
    add_fcat 'MAKTX'        'Description'.
    add_fcat 'BDTER'        'Requirement Date'.
    add_fcat 'BDMNG'        'Requirement QTY'.
    add_fcat 'LABST'        'Current Stock'.
    add_fcat 'PO_QTY'       'PO QTY'.
    add_fcat 'STOCK'        'Stock Allocation'.
    add_fcat 'SHORT'        'Shortage'.


ENDFORM.
