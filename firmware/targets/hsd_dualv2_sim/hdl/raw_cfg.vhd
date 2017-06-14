configuration raw_cfg of hsd_fex_wrapper is
  for mapping
    for U_FEX : hsd_fex
      use entity work.hsd_raw;
    end for;
  end for;
end configuration;
  
