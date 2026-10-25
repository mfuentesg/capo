import { createApi } from "@/lib/supabase/factory"
import * as teamsApi from "./teamsApi"

/**
 * Teams API
 *
 * Auto-detects server vs client context and uses appropriate Supabase client.
 * Can be used in both Server Components and Client Components.
 */
export { teamsApi as rawApi }
export const api = createApi(teamsApi)

// Re-export functions
export {
  getTeams,
  getTeamsWithClient,
  getTeam,
  getTeamWithClient,
  createTeam,
  updateTeam,
  deleteTeam,
  leaveTeam,
  getTeamMembers,
  getTeamMembersWithClient,
  getTeamInvitations,
  acceptTeamInvitation,
  deleteTeamInvitation,
  getPendingInvitations,
  declineTeamInvitation,
  resendTeamInvitation,
  changeTeamMemberRole,
  transferTeamOwnership
} from "./teamsApi"

// Re-export types
export type { Tables, TablesInsert, TablesUpdate } from "@/lib/supabase/database.types"
export type { TeamWithMemberCount } from "./teamsApi"
