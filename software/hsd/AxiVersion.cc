#include "hsd/AxiVersion.hh"

std::string Pds::HSD::AxiVersion::buildStamp() const
{
  uint32_t tmp[64];
  for(unsigned i=0; i<64; i++)
    tmp[i] = BuildStamp[i];
  return std::string(reinterpret_cast<const char*>(tmp));
}

